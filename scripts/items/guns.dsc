#One minor difference between this and Val:
#When you pick up a gun from the ground, the gun you bought in the buy phase is removed and money is recovered
#instead of dropped too.

fort_gun_handler:
  type: world
  debug: false
  definitions: data
  events:
    #"disable" left clicking with guns
    on player left clicks block with:gun_*:
    - determine passively cancelled
    - cast FAST_DIGGING amplifier:9999 duration:1s no_icon no_ambient hide_particles

    on player right clicks block with:gun_*:
    - determine passively cancelled

    #-cancel shooting while trying to reload

    - define gun        <player.item_in_hand>
    - define gun_name   <[gun].script.name.after[_]>

    #-out of ammo check

    #all NON-AUTO guns have cooldowns
    - if <player.has_flag[fort.<[gun_name]>.cooldown]>:
      - stop

    - flag player gun_holding_down duration:5t

    - if <player.has_flag[is_shooting]>:
      - stop

    - run fort_gun_handler.shoot def:<map[gun=<[gun]>]>


  ## - [ Shoot Stuff ] - ##
  shoot:

    - define world           <player.world>
    - define gun             <[data].get[gun]>
    - define gun_name        <[gun].script.name.after[_]>

    - define rarity              <[gun].flag[rarity]>
    - define base_damage         <[gun].flag[rarities.<[rarity]>.damage]>
    - define pellets             <[gun].flag[pellets]>
    - define base_bloom          <[gun].flag[base_bloom]>
    - define bloom_multiplier    <[gun].flag[bloom_multiplier]>
    - define headshot_multiplier <[gun].flag[headshot_multiplier]>

    - define custom_recoil_fx     <[gun].flag[custom_recoil_fx]>
    #phantom / vandal = 2
    #
    - define ticks_between_shots <[gun].flag[ticks_between_shots]||3>
    - define mod_value           <[ticks_between_shots].equals[1].if_true[0].if_false[1]>

    - if <[gun].has_flag[cooldown]>:
      - flag player fort.<[gun_name]>.cooldown duration:<[gun].flag[cooldown]>s

    - flag player is_shooting
    - while <player.has_flag[gun_holding_down]> && <player.is_online> && <player.item_in_hand> == <[gun]>:
      #do 1 instead of 0 so there's no delay on the first shot
      - if <[loop_index].mod[<[ticks_between_shots]>]> == <[mod_value]>:

        - define times_shot <[ticks_between_shots].equals[1].if_true[<[loop_index]>].if_false[<[loop_index].div[<[ticks_between_shots]>].round_down.add[1]>]>
        - run fort_gun_handler.recoil def:<map[gun_name=<[gun_name]>]>

        - inject fort_gun_handler.fire

        #sound
        - foreach <[gun].flag[Sounds].keys> as:sound:
          - define pitch <[gun].flag[Sounds.<[sound]>.Pitch]>
          - define volume <[gun].flag[Sounds.<[sound]>.Volume]>
          - playsound <player.location> sound:<[sound]> pitch:<[pitch]> volume:<[volume]>

        #- inject fort_gun_handler.ammo
        #- inject fort_gun_handler.empty_gun_check

        - flag player is_shooting.loc:<player.location>
        - if <[gun].has_flag[cooldown]> && <[times_shot]> == 1:
          - while stop

      - wait 0.5t
    - flag player is_shooting:!

  fire:
  #required definitions:
  # - <[pellets]>

    - repeat <[pellets]>:

      #eye loc is used for the particle effects
      - define eye_loc    <player.eye_location>
      #origin is the actual origin point to destination ray
      - define origin     <[eye_loc]>

      # - [ Simple bloom calculator ] - #
      - define bloom <[base_bloom]>
      #if the player is in the air
      - if !<player.location.y.mul[16].is_integer>:
        - define bloom:+:0.75
      #if they're walking, increase bloom
      - if <player.has_flag[is_shooting.loc]> && <player.location.with_pose[0,0]> != <player.flag[is_shooting.loc].with_pose[0,0]>:
        - define bloom:+:0.5
      #if they're spamming, increase bloom
      - if <[times_shot]> > 1:
        - define bloom:+:0.5
      - define bloom <[bloom].mul[<[bloom_multiplier]>]>
      #apply bloom
      - define new_pitch <[origin].pitch.add[<util.random.decimal[-<[bloom]>].to[<[bloom]>]>]>
      - define new_yaw   <[origin].yaw.add[<util.random.decimal[-<[bloom]>].to[<[bloom]>]>]>
      - define origin    <[origin].with_pitch[<[new_pitch]>].with_yaw[<[new_yaw]>]>

      # - [ Ray ] - #
      #where the particle effect starts from
      #make it a procedure for each gun in the future?
      - define particle_origin <[origin].forward.relative[-0.33,-0.2,0.3]>
      - define ignored_entities <server.online_players.filter[gamemode.equals[SPECTATOR]].include[<player>].include[<[world].entities[armor_stand]>]>

      - define target          <[origin].ray_trace_target[ignore=<[ignored_entities]>;ray_size=1;range=200]||null>
      - define target_loc      <[origin].ray_trace[range=200;entities=*;ignore=<[ignored_entities]>;default=air]>

      - inject fort_gun_handler.shoot_fx

      # - [ Damage ] - #
      - if <[target]> != null && <[target].is_spawned>:

        # - [ Damage Falloff ] - #
        #maybe for future: to calculate distances, use the tiles provided in the wiki for distances and convert to tile sizes in mc for 1:1
        - define distance <[target_loc].distance[<[origin]>]>
        #1 = no damage falloff
        #0 = all damage gone
        #start off with 100% damage falloff
        - define damage_falloff 0
        - define distance_condensor 1.5
        - foreach <[gun].flag[damage_falloff].keys> as:max_dist:

          #since the distance from fortnite lengths doesn't exactly translate to mc lengths
          - define actual_max_dist <[max_dist].div[<[distance_condensor]>]>
          - if <[distance]> < <[actual_max_dist]>:
            - if <[loop_index]> == 1:
              - define damage_falloff 1
              - foreach stop

            - define max_falloff   <[gun].flag[damage_falloff.<[max_dist]>]>

            - if <[max_falloff]> == 0:
              - define damage_falloff 0
              - foreach stop

            - define min_dist        <[gun].flag[damage_falloff].keys.get[<[loop_index].sub[1]>]>
            - define actual_min_dist <[min_dist].div[<[distance_condensor]>]>
            - define min_falloff     <[gun].flag[damage_falloff.<[min_dist]>]>

            - define progress     <[distance].sub[<[actual_min_dist]>].div[<[actual_max_dist].sub[<[actual_min_dist]>]>]>

            - define damage_falloff <[min_falloff].sub[<[min_falloff].sub[<[max_falloff]>].mul[<[progress]>]>].div[100]>
            - foreach stop

        - define damage <[base_damage].div[<[pellets]>].mul[<[damage_falloff]>]>

        #if it's headshot, multiply damage by headshot multiplier
        - define part_height <[target_loc].round_to[1].y.sub[<[target].location.y>]>
        - foreach <list[0.7|1.4|1.9]> as:height:
          - if <[part_height]> >= 0 && <[part_height]> <= <[height]>:
            - define body_part <list[Legs|Body|Head].get[<[Loop_Index]>]>
            - foreach stop

        - define damage <[damage].mul[<[headshot_multiplier]>]> if:<[body_part].equals[Head]>

        - narrate <[damage]>

        #- hurt <[damage]> <[target]> source:<player>
        - if <[target].is_living>:
          - adjust <[target]> no_damage_duration:0

        - adjust <player> reset_attack_cooldown


  camera_shake:
  #default: 0.094
  - define mult <[data].get[mult]>
  - adjust <player> fov_multiplier:<[mult]>
  - wait 2t
  - adjust <player> fov_multiplier

  recoil:

    - define gun_name <[data].get[gun_name]>
    - choose <[gun_name]>:
      - case pump_shotgun:
        - run fort_gun_handler.camera_shake def:<map[mult=0.08]>
        - define recoil 2
        - repeat <[recoil]>:
          - define pitch_sub <[value].div[1.5]>
          - look <player> yaw:<player.location.yaw> pitch:<player.location.pitch.sub[<[pitch_sub]>]> offthread_repeat:3
          - wait 1t
        - repeat <[recoil].mul[4]>:
          - define pitch_sub <element[8].sub[<[value]>].sub[6].div[10]>
          - look <player> yaw:<player.location.yaw> pitch:<player.location.pitch.sub[<[pitch_sub]>]> offthread_repeat:3
          - wait 1t
      - default:
        - run fort_gun_handler.camera_shake def:<map[mult=0.0965]>
        - look <player> yaw:<player.location.yaw> pitch:<player.location.pitch.sub[0.7]> offthread_repeat:3
        - repeat 4:
          - look <player> yaw:<player.location.yaw> pitch:<player.location.pitch.add[0.175]> offthread_repeat:3
          - wait 1t

  shoot_fx:
    - if <player.is_sneaking> && <[gun].has_flag[has_scope]>:
      #scoped origin
      - define particle_origin <[eye_loc].forward[1.8].below[0.25]>
    - else:
      #default origin
      - define particle_origin <[eye_loc].forward.relative[-0.33,-0.2,0.3]>

    #checking for value so it doesn't repeat the same amount of pellets
    - if <[value]> == 1:
      - if <[custom_recoil_fx]>:
        - run fort_gun_handler.custom_recoil_fx.<[gun_name]> def:<map[particle_origin=<[particle_origin]>]>
      - else:
        - run fort_gun_handler.default_recoil_fx def:<map[particle_origin=<[particle_origin]>]>

    # - [ "Base" Shoot FX ] - #
    - define trail <[particle_origin].points_between[<[target_loc]>].distance[7]>

    # - Points Between (Potential: CRIT, WAX_ON, SCRAPE, ELECTRIC_SPARK, BLOCK_DUST, DRIP_LAVA, FALLING_NECTAR, DRIPPING_HONEY, END_ROD,ENCHANTMENT_TABLE)
    - define between <[particle_origin].points_between[<[target_loc]>].distance[0.5]>
    - playeffect at:<[between]> effect:CRIT offset:0 visibility:500

    # - Impact (Potential: CAMPFIRE_COSY_SMOKE, SMOKE_NORMAL, SQUID_INK)
    - define particle_dest <[target_loc].face[<[eye_loc]>].forward[0.1]>
    - playeffect at:<[particle_dest]> effect:sweep_attack offset:0 quantity:1 visibility:500 velocity:1.65,1.65,1.65

    # - Blood / Material hit
    - define mat <player.cursor_on.material.name||null>
    - if <[target]> != null:
      #splatter: red_glazed_terracotta
      - playeffect at:<[particle_dest]> effect:BLOCK_CRACK offset:0 quantity:3 visibility:500 special_data:red_wool
    - else if <[mat]> != null:
      - playeffect at:<[particle_dest]> effect:BLOCK_CRACK offset:0 quantity:8 visibility:500 special_data:<[mat]>

  default_recoil_fx:
    - define particle_origin <[data].get[particle_origin]>

    - define neg  <proc[spacing].context[-50]>
    - define text <[neg]><&chr[000<util.random.int[4].to[6]>].font[muzzle_flash]><[neg]>
    - spawn <entity[armor_stand].with[custom_name=<[text]>;custom_name_visible=true;gravity=false;collidable=false;invulnerable=true;visible=false]> <[particle_origin].below[2.4]> save:flash
    - define flash <entry[flash].spawned_entity>

    - wait 2t
    - remove <[flash]>

  custom_recoil_fx:

    pump_shotgun:
      - define particle_origin <[data].get[particle_origin]>

      - define neg  <proc[spacing].context[-50]>
      - define text <[neg]><&chr[000<util.random.int[1].to[3]>].font[muzzle_flash]><[neg]>

      - spawn <entity[armor_stand].with[custom_name=<[text]>;custom_name_visible=true;gravity=false;collidable=false;invulnerable=true;visible=false]> <[particle_origin].below[2.5]> save:flash
      - define flash <entry[flash].spawned_entity>

      - wait 2t
      - remove <[flash]>
      - playeffect at:<[particle_origin]> effect:SMOKE_NORMAL offset:0.05 quantity:1 visibility:500

#@ [ Gun Data ] @#

gun_pump_shotgun:
  type: item
  material: wooden_hoe
  display name: <&f><&l>PUMP SHOTGUN
  mechanisms:
    custom_model_data: 1
    hides: ALL
  flags:
    #this value can be changed
    rarity: common
    icon_chr: 1
    #global stats
    #min is 5 if you want singular shots
    ticks_between_shots: 5
    mag_size: 5
    #in seconds
    cooldown: 1
    #how many pellets in one shot
    pellets: 10
    base_bloom: 1.8
    bloom_multiplier: 1
    headshot_multiplier: 2
    #if there's a slightly different shoot effect alongside the base ones
    custom_recoil_fx: true
    #rarity-based states
    rarities:
      common:
        damage: 92
        reload_time: 5.1
        custom_model_data: x
      uncommon:
        damage: 101
        reload_time: 4.8
        custom_model_data: x
      rare:
        damage: 110
        reload_time: 4.4
        custom_model_data: x
      epic:
        damage: 119
        reload_time: 4.0
        custom_model_data: x
      legendary:
        damage: 128
        reload_time: 3.7
        custom_model_data: x
    #(in meters/blocks)
    #value is in percentage of damage
    #max means it wont deal any damage past that
    damage_falloff:
      7: 100
      10: 78
      15: 49
      31: 0

    sounds:
      ENTITY_FIREWORK_ROCKET_LARGE_BLAST:
        pitch: 0.8
        volume: 1.2
      ENTITY_DRAGON_FIREBALL_EXPLODE:
        pitch: 1.8
        volume: 1.2

gun_assault_rifle:
  type: item
  material: wooden_hoe
  display name: <&f><&l>ASSAULT RIFLE
  mechanisms:
    custom_model_data: 1
    hides: ALL
  flags:
    #this value can be changed
    rarity: common
    icon_chr: 1
    #global stats
    #min is 5 if you want singular shots
    ticks_between_shots: 4
    mag_size: 30
    #in seconds
    #cooldown: 0
    pellets: 1
    base_bloom: 1.2
    bloom_multiplier: 1
    headshot_multiplier: 1.5
    custom_recoil_fx: false
    rarities:
      common:
        damage: 30
        reload_time: 2.7
        custom_model_data: x
      uncommon:
        damage: 31
        reload_time: 2.6
        custom_model_data: x
      rare:
        damage: 33
        reload_time: 2.5
        custom_model_data: x
      epic:
        damage: 35
        reload_time: 2.4
        custom_model_data: x
      legendary:
        damage: 36
        reload_time: 2.2
        custom_model_data: x
    #(in meters)
    #value is in percentage of damage
    damage_falloff:
      50: 100
      75: 80
      95: 66

    sounds:
      ENTITY_FIREWORK_ROCKET_BLAST_FAR:
        pitch: 1.07
        volume: 1.2
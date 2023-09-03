fort_emote_handler:
  type: world
  debug: false
  events:
    on player clicks in inventory slot:2|3|4|5:
    - define emote <map[2=default;3=none;4=none;5=none].get[<context.slot>]>

    #second check is for if they're already emoting
    - if <[emote]> == none || <player.has_flag[fort.emote]>:
      - stop

    - choose <[emote]>:
      - case default:
        - define sound fort.emotes.default.<util.random.int[1].to[3]>
        - playsound <player.location> custom sound:<[sound]> volume:1.2

    #- run pmodels_spawn_model def.location:<player.location.above[2]> def.player:<player> def.scale:<location[1.87,1.87,1.87]> save:result
    - run dmodels_spawn_model def.player:<player> def.model_name:emotes def.location:<player.location.above[2]> save:result
    - define spawned <entry[result].created_queue.determination.first||null>
    - if !<[spawned].is_truthy>:
        - narrate "<&[error]>Emote spawning failed?"
        - stop

    #- run dmodels_set_yaw def.root_entity:<[spawned]> def.yaw:<player.location.yaw>
    - run dmodels_set_scale def.root_entity:<[spawned]> def.scale:1.87,1.87,1.87

    - flag player fort.emote.sound:<[sound]>
    - flag player spawned_dmodel_emotes:<[spawned]>
    - flag <[spawned]> emote_host:<player>
    - run dmodels_animate def.root_entity:<[spawned]> def.animation:<[emote]>

    #this flag is added in dmodels_animating.dsc for the third person viewer
    #this event also fires when the player goes offline (but doesnt work?)
    on player exits vehicle flagged:fort.emote:
    - foreach <player.location.find_players_within[10]> as:p:
      - adjust <[p]> stop_sound:<player.flag[fort.emote.sound]>
    - flag player fort.emote:!

    on player quits flagged:fort.emote:
    - foreach <player.location.find_players_within[10]> as:p:
      - adjust <[p]> stop_sound:<player.flag[fort.emote.sound]>
    - invisible <player> false
    - if <player.has_flag[spawned_dmodel_emotes]>:
      - define model <player.flag[spawned_dmodel_emotes]>
      - define cam   <[model].flag[camera]>
      - define stand <[model].flag[stand]>
      - remove <[cam]> if:<[cam].is_spawned>
      - remove <[stand]> if:<[stand].is_spawned>
    - flag player fort.emote:!
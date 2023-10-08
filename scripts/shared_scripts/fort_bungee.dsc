fort_bungee_handler:
    #-in case the server closes and it reopens thinking a game server is open even though it isn't
    on bungee server connects:
    - if <context.server> == fort_lobby && <bungee.server> != fort_lobby && <bungee.server.starts_with[fort_]>:
      - define status <server.has_flag[fort.temp.available].if_true[AVAILABLE].if_false[UNAVAILABLE]>
      - definemap data:
          game_server: <bungee.server>
          status: <[status]>
          mode: <server.flag[fort.mode]||solo>
          players: <server.online_players_flagged[fort]>
      - bungeerun fort_lobby fort_bungee_handler.set_data def:<[data]>



fort_bungee_tasks:
  type: task
  debug: false
  definitions: data
  script:
    - narrate "do bungee tings"
  set_data:

    #instead of having available_servers flag, have only .servers flag and have a status key?

    - define game_server <[data].get[game_server]>
    - define status      <[data].get[status]>
    - define mode        <[data].get[mode]>

    - choose <[status]>:
      - case AVAILABLE:
        - define players     <[data].get[players]>
        - flag server fort.available_servers.<[mode]>.<[game_server]>.players:<[players]>
        - announce "<&b>[Nimnite]<&r> Game server <&b><[game_server]><&r> is now <&a>AVAILABLE<&r>. Mode: <&e><[mode]>" to_console
      - case UNAVAILABLE:
        - flag server fort.available_servers.<[mode]>.<[game_server]>:!
        - announce "<&b>[Nimnite]<&r> Game server <&b><[game_server]><&r> is now <&c>CLOSED<&r>" to_console
      - default:
        - flag server fort.available_servers.<[mode]>.<[game_server]>:!
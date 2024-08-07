package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

/* TODO(Dhumil):
-[] score : two modes
    - score based on points / pair
-[] juice up the hover, focus and select effect
-[] better color for ui_buttons
-[] add button ui sounds
*/

WIDTH       :: 1920
HEIGHT      :: 1080
CARD_WIDTH  :: 140
CARD_HEIGHT :: 190
MAX_CARDS   :: 53
GRID_WIDTH  :: 6
GRID_HEIGHT :: 4
DECK_SIZE   :: GRID_WIDTH * GRID_HEIGHT

card_subtexture: [MAX_CARDS]rl.Vector2 = {
    {0,3}, {1,2}, {1,1}, {1,0}, {0,9}, {0,8}, {0,7}, {0,6}, {0,5}, {0,4}, {0,2}, {0,0}, {0,1},
    {1,7}, {5,2}, {2,5}, {2,4}, {2,3}, {2,2}, {2,1}, {2,0}, {1,9}, {1,8}, {1,6}, {1,4}, {1,5},
    {3,0}, {3,9}, {3,8}, {3,7}, {3,6}, {3,5}, {3,4}, {3,3}, {3,2}, {3,1}, {2,9}, {2,7}, {2,8},
    {4,3}, {2,6}, {5,1}, {5,0}, {4,9}, {4,8}, {4,7}, {4,6}, {4,5}, {4,4}, {4,2}, {4,0}, {4,1},
    {1,3}
};

GuiId :: distinct u64

Asset :: struct {
    card_texture    : rl.Texture,
    cardback_texture: rl.Texture,
    card_place_sound: rl.Sound,
    card_flip_sound : rl.Sound,
}

cw :: f32(CARD_WIDTH)*1.25
ch :: f32(CARD_HEIGHT)*1.25

load_assets :: proc(using assets: ^Asset) {
    //Load Texturess
    card_texture = rl.LoadTexture("data/playingCards.png")
    cardback_texture = rl.LoadTexture("data/playingCardBacks.png")
    //Load Sound
    card_place_sound = rl.LoadSound("data/card-place-2.wav")
    card_flip_sound = rl.LoadSound("data/card-place-1.wav")
    rl.SetSoundVolume(card_place_sound, .8)
    rl.SetSoundVolume(card_flip_sound, .8)
}

unload_assets :: proc(using assets: ^Asset) {
    defer rl.UnloadTexture(card_texture)
    defer rl.UnloadTexture(cardback_texture)
    defer rl.UnloadSound(card_place_sound)
    defer rl.UnloadSound(card_flip_sound)
}

draw_table :: proc(using game: ^Game, using assets: ^Asset) {
    sw := f32(WIDTH)
    sh := f32(HEIGHT)
    origin := rl.Vector2{cw*0.5, ch*0.5}
    //Draw Cards
    for card in deck {
        if card.state == .COLLECTED {
            continue
        }
        src := rl.Rectangle {
            card_subtexture[card.id].x * CARD_WIDTH,
            card_subtexture[card.id].y * CARD_HEIGHT,
            CARD_WIDTH, CARD_HEIGHT
        }
        rect := rl.Rectangle{card.pos.x, card.pos.y, cw, ch}

        #partial switch card.state {
            case .SHOW:
            rl.DrawTexturePro(card_texture, src, rect, origin, 0, card.tint)
            case .SELECTED:
            src.x = 0*src.width
            src.y = 3*src.height
            rl.DrawTexturePro(cardback_texture, src, rect, origin, 0, card.tint)
            case .NORMAL:
            src.x = 0*src.width
            src.y = 3*src.height
            rl.DrawTexturePro(cardback_texture, src, rect, origin, 0, card.tint)
        }
    }

    if state != .MENU && game.show_gameplay_ui {// Draw player and opponent
        FONT_SIZE :: 30
        bg_rect: rl.Rectangle
        bg_rect.width = 700
        bg_rect.height = ch + 100
        bg_rect.x = f32(GRID_WIDTH*cw + cw*.7)
        bg_rect.y = f32(sh*.5 + ch*.3)
        rl.DrawRectangleRec(bg_rect, {30, 30, 30, 70})
        for card_id in player_card {
            card := deck[card_id]
            src := rl.Rectangle{
                card_subtexture[card.id].x * CARD_WIDTH,
                card_subtexture[card.id].y * CARD_HEIGHT,
                CARD_WIDTH, CARD_HEIGHT
            }
            rect := rl.Rectangle{card.pos.x, card.pos.y, cw, ch}
            rl.DrawTexturePro(card_texture, src, rect, origin, 0, card.tint)
        }
        rl.DrawText(rl.TextFormat("Player : %d", player_score.ui_value),
            i32(bg_rect.x+20), i32(bg_rect.y+15),
            FONT_SIZE, rl.WHITE)

        bg_rect.y = f32(sh*.5 - ch*.3 - bg_rect.height)
        rl.DrawRectangleRec(bg_rect, {30, 30, 30, 70})
        for card_id in opponent_card {
            card := deck[card_id]
            src := rl.Rectangle{
                card_subtexture[card.id].x * CARD_WIDTH,
                card_subtexture[card.id].y * CARD_HEIGHT,
                CARD_WIDTH, CARD_HEIGHT
            }
            rect := rl.Rectangle{card.pos.x, card.pos.y, cw, ch}
            rl.DrawTexturePro(card_texture, src, rect, origin, 0, card.tint)
        }
        rl.DrawText(rl.TextFormat("Opponent : %d", ai_score.ui_value),
            i32(bg_rect.x+20), i32(bg_rect.y+bg_rect.height-FONT_SIZE-10),
            FONT_SIZE, rl.WHITE)
    }
}

main :: proc()
{
    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(1280, 720, "Game")
    defer rl.CloseWindow()
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    assets: Asset
    load_assets(&assets)
    defer unload_assets(&assets)

    n := (GRID_WIDTH * GRID_HEIGHT) / 2
    game: Game
    game.state = .MENU
    game.turn_state = .PLAYER
    game.mode = .NORMAL
    game.show_gameplay_ui = false
    game.player_state = .FIRST_CARD
    game.player_score = {0,0,0,false}
    game.ai_score = {0,0,0,false}
    game.deck = make([]Card, DECK_SIZE); make_card_deck(&game.deck);
    game.player_card = make([dynamic]u32)
    game.opponent_card = make([dynamic]u32)
    game.ai_memory = make([dynamic]u32)
    defer delete(game.player_card)
    defer delete(game.opponent_card)
    defer delete(game.deck)
    defer delete(game.ai_memory)

    event: EventSystem
    render_texture := rl.LoadRenderTexture(WIDTH, HEIGHT)
	defer rl.UnloadRenderTexture(render_texture)

    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose()
    {
        free_all(context.temp_allocator)

        { // scale mouse position
            w := f32(WIDTH)
            h := f32(HEIGHT)

            sw := f32(max(rl.GetScreenWidth(), 1))
            sh := f32(max(rl.GetScreenHeight(), 1))

            mouse_pos := rl.GetMousePosition()
            mouse_pos.x /= sw
            mouse_pos.y /= sh

            scale := min(sw/w, sh/h)

            mouse_pos.x -= 0.5
            mouse_pos.y -= 0.5
            mouse_pos.x *= sw/(scale*w)
            mouse_pos.y *= sh/(scale*h)
            mouse_pos.x += 0.5
            mouse_pos.y += 0.5

            mouse_pos.x *= w
            mouse_pos.y *= h

            event.mouse_pos = mouse_pos
        }

        game.dt = rl.GetFrameTime()
        time := f32(rl.GetTime())

        update_score(&game.player_score, game.dt)
        update_score(&game.ai_score, game.dt)
        update_cards(&game, &assets, time)

        #partial switch game.state {
        case .GAMEPLAY:
            { //check win/loose condition
                if len(game.player_card) + len(game.opponent_card) == n {
                    if game.player_score.value > game.ai_score.value {
                        game.state = .WIN
                        set_card_win_pos(&game.deck, &game.player_card)
                    } else if game.player_score.value < game.ai_score.value {
                        game.state = .LOOSE
                        set_card_win_pos(&game.deck, &game.opponent_card)
                    } else {
                        game.state = .DRAW
                    }
                }
            }

            if !game.show_gameplay_ui {
                if time - game.game_start_time >= 1.4 {
                    game.show_gameplay_ui = true
                }
            }

            switch game.turn_state {
            case .PLAYER:
                player_input(&game, &event, &assets)
            case .AI:
                ai_update(&game, &assets)
            }

            if game.player_state == .CHECK_CARD {
                game.check_timer += game.dt
                if game.check_timer > .4 {
                    if game.deck[game.first_id].value == game.deck[game.second_id].value &&
                    game.deck[game.first_id].suit == game.deck[game.second_id].suit {
                        collect_card(&game)
                    } else {
                        game.deck[game.first_id].state = .NORMAL
                        game.deck[game.second_id].state = .NORMAL
                    }
                    //change turn
                    if game.turn_state == .PLAYER {
                        game.turn_state = .AI
                    } else {
                        game.turn_state = .PLAYER
                    }
                    game.player_state = .FIRST_CARD
                }
            }
        case .WIN:
            card_win_effect(&game.deck, &game.player_card, 3)
        case .LOOSE:
            card_win_effect(&game.deck, &game.opponent_card, 3)
        }

        {// game drawing stuff
        rl.BeginTextureMode(render_texture);
        rl.ClearBackground({36, 100, 50, 255})
        draw_table(&game, &assets)

        sw := f32(WIDTH)
        sh := f32(HEIGHT)
        x_left := GRID_WIDTH*cw
        switch game.state { // Draw UI
            case .MENU:
                rect := rl.Rectangle{x_left + (sw-x_left)*.31, sh*.57, 200, 70}
                color := rl.Color{36, 125, 50, 255}
                btn_text := fmt.tprintf("%s", game.mode)
                game_mode_btn := create_text_button(1, rect, rl.WHITE, btn_text)
                rect.y += rect.height + 10
                start_button := create_button(2, rect, color, "Start Game")
                update_button(&game_mode_btn, &event)
                update_button(&start_button, &event)
                if game_mode_btn.clicked {
                    game.mode = GameMode((int(game.mode) + 1) % 2)
                }
                if start_button.clicked {
                    game.state = .GAMEPLAY
                    game.game_start_time = time
                    for &card, i in game.deck {
                        target: rl.Vector2
                        target.x = cw*.7 + f32(i%GRID_WIDTH) * cw*1.05
                        target.y = ch*.7 + f32(i/GRID_WIDTH) * ch*1.05
                        set_tween(&card, target, .2, time + f32(i)*.05)
                    }
                }
            case .GAMEPLAY:
                if game.show_gameplay_ui {
                    rl.DrawText(rl.TextFormat("Turn : %s", game.turn_state), i32(sw*.6), 35, 28, rl.WHITE)
                }
            case .WIN:
                rect := rl.Rectangle{sw*.7, sh*.5, 200, 70}
                color := rl.Color{36, 125, 50, 255}
                restart_button := create_button(1, rect, color, "Restart")
                rect.x += rect.width + 50
                menu_btn := create_button(2, rect, color, "Menu")
                update_button(&restart_button, &event)
                update_button(&menu_btn, &event)
                if restart_button.clicked {
                    restart_game(&game);
                }
                if menu_btn.clicked {
                    goto_menu(&game)
                }
                rl.DrawText("You Won!", i32(x_left*.45), 130, 58, rl.WHITE)
            case .LOOSE:
                rect := rl.Rectangle{sw*.7, sh*.5, 200, 70}
                color := rl.Color{36, 125, 50, 255}
                restart_button := create_button(1, rect, color, "Restart")
                rect.x += rect.width + 50
                menu_btn := create_button(2, rect, color, "Menu")
                update_button(&restart_button, &event)
                update_button(&menu_btn, &event)
                if restart_button.clicked {
                    restart_game(&game);
                }
                if menu_btn.clicked {
                    goto_menu(&game)
                }
                rl.DrawText("You Loose!", i32(x_left*.45), 130, 58, rl.WHITE)
            case .DRAW:
                rect := rl.Rectangle{sw*.7, sh*.5, 200, 70}
                color := rl.Color{36, 125, 50, 255}
                restart_button := create_button(1, rect, color, "Restart")
                rect.x += rect.width + 50
                menu_btn := create_button(2, rect, color, "Menu")
                update_button(&restart_button, &event)
                update_button(&menu_btn, &event)
                if restart_button.clicked {
                    restart_game(&game);
                }
                if menu_btn.clicked {
                    goto_menu(&game)
                }
                rl.DrawText("Match Draw", i32(sw*.4), 20, 28, rl.WHITE)
        }
        rl.EndTextureMode()

        rl.BeginDrawing();
        rl.ClearBackground({0,0,0,0})
        {
			w := f32(WIDTH)
			h := f32(HEIGHT)
			source := rl.Rectangle{0, 0, w, h}
			dst := source

			sw := f32(rl.GetScreenWidth())
			sh := f32(rl.GetScreenHeight())
			scale := min(sw/w, sh/h)
			dst.width  = scale * f32(dst.width)
			dst.height = scale * f32(dst.height)

			dst.x = (sw - dst.width)  * 0.5
			dst.y = (sh - dst.height) * 0.5


			source.height = -source.height
			rl.DrawTexturePro(
				texture  = render_texture.texture,
				source   = source,
				dest     = dst,
				origin   = {0, 0},
				rotation = 0,
				tint     = rl.WHITE,
			)
		}
        rl.DrawFPS(2, 2);
        rl.EndDrawing();
        }

        {// end input handling
            if !event.updated_focus {
                event.focus_id = 0
            }
            event.updated_focus = false
            event.clicked_id = 0
            event.last_mouse_pos = event.mouse_pos
        }
    }
}

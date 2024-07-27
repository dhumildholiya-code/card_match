package game

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

WIDTH       :: 1280
HEIGHT      :: 720
CARD_WIDTH  :: 140
CARD_HEIGHT :: 190
MAX_CARDS   :: 53
GRID_WIDTH  :: 6
GRID_HEIGHT :: 4

card_subtexture: [MAX_CARDS]rl.Vector2 = {
    {0,3}, {1,2}, {1,1}, {1,0}, {0,9}, {0,8}, {0,7}, {0,6}, {0,5}, {0,4}, {0,2}, {0,0}, {0,1},
    {1,7}, {5,2}, {2,5}, {2,4}, {2,3}, {2,2}, {2,1}, {2,0}, {1,9}, {1,8}, {1,6}, {1,4}, {1,5},
    {3,0}, {3,9}, {3,8}, {3,7}, {3,6}, {3,5}, {3,4}, {3,3}, {3,2}, {3,1}, {2,9}, {2,7}, {2,8},
    {4,3}, {2,6}, {5,1}, {5,0}, {4,9}, {4,8}, {4,7}, {4,6}, {4,5}, {4,4}, {4,2}, {4,0}, {4,1},
    {1,3}
};

GuiId :: distinct u64

CardSuit :: enum {
    NONE,
    SPADE,
    HEART,
    DIAMOND,
    CLUB,
}

CardValue :: enum {
    JOKER,
    ACE,
    TWO,
    THREE,
    FOUR,
    FIVE,
    SIX,
    SEVEN,
    EIGHT,
    NINE,
    TEN,
    JACK,
    QUEEN,
    KING,
}

CardState :: enum {
    NORMAL,
    SHOW,
    SELECTED,
    COLLECTED
}

Card :: struct {
    id      : u32,
    suit    : CardSuit,
    value   : CardValue,
    state   : CardState,
    pos     : rl.Vector2,
    v_pos   : rl.Vector2,
    t       : f32,
    tint    : rl.Color,
}

Button :: struct {
    id      : GuiId,
    rect    : rl.Rectangle,
    origin  : rl.Vector2,
    color   : rl.Color,
    text    : string,
    clicked : bool,
}

EventSystem :: struct {
    hover_id, focus_id, last_id: GuiId,
    clicked_id: GuiId,
    updated_focus: bool,

    mouse_pos, last_mouse_pos: rl.Vector2,
}

PlayerState :: enum {
    FIRST_CARD,
    SECOND_CARD,
    CHECK_CARD,
}

TurnState :: enum {
    PLAYER,
    AI
}

GameState :: enum {
    MENU,
    GAMEPLAY,
    WIN,
    LOOSE,
    DRAW,
}

Game :: struct {
    state           : GameState,
    player_state    : PlayerState,
    turn_state      : TurnState,
    deck            : [dynamic]Card,
    player_card     : [dynamic]u32,
    opponent_card   : [dynamic]u32,
    player_point    : int,
    ai_point        : int,
    ai_memory       : [dynamic]u32,

    dt              : f32,
    check_timer     : f32,
    ai_timer        : f32,
    first_id        : u32,
    second_id       : u32,
}

make_card :: proc(id: u32) -> Card {
    if id == 52{
        return Card{
            id      = id,
            suit    = .NONE,
            value   = .JOKER,
            state   = .NORMAL,
            tint    = rl.WHITE,
        }
    } else {
        return Card{
            id      = id,
            suit    = CardSuit(id/13 + 1),
            value   = CardValue(id%13 + 1),
            state   = .NORMAL,
            tint    = rl.WHITE,
        }
    }
}

card_value :: proc(card: Card) -> int {
    if card.value == .JOKER {
        return 13
    } else if card.value == .ACE {
        return 11
    } else {
        return int(card.value)
    }
}

make_card_deck :: proc(deck: ^[dynamic]Card) {
    n := (GRID_WIDTH * GRID_HEIGHT) / 2
    all_cards := make([dynamic]u32, context.temp_allocator)
    for i in 0..<MAX_CARDS {
        append(&all_cards, u32(i))
    }
    rand.shuffle(all_cards[:])

    for i in 0..<n {
        id := all_cards[i]
        append(deck, make_card(id))
        append(deck, make_card(id))
    }
    rand.shuffle(deck[:])

    for &card in deck {
        card.pos.x = cw*.7
        card.pos.y = ch*.7
    }
}

add_distinct_memory :: proc(memory: ^[dynamic]u32, data: u32) {
    for e in memory {
        if e == data {
            return
        }
    }
    append(memory, data)
}

remove_memory :: proc(memory: ^[dynamic]u32, data: u32) {
    #reverse for e, i in memory {
        if e == data {
            unordered_remove(memory, i)
            break
        }
    }
}

check_memory :: proc(memory: ^[dynamic]u32, deck: ^[dynamic]Card, check_id: u32) -> (id: u32, matched: bool) {
    for data, i in memory {
        if data == check_id {
            continue
        }
        if deck[data].value == deck[check_id].value && deck[data].suit == deck[check_id].suit {
            unordered_remove(memory, i)
            remove_memory(memory, check_id)
            return data, true
        }
    }
    return 0, false
}

set_focus :: proc(using event: ^EventSystem, id: GuiId) {
    focus_id = id
    updated_focus = true
}

update_control :: proc(using event: ^EventSystem, id: GuiId, rect: rl.Rectangle, hold_focus := false) {
    mouse_over := rl.CheckCollisionPointRec(mouse_pos, rect)
    if focus_id == id {
        updated_focus = true
    }
    if mouse_over && !rl.IsMouseButtonDown(.LEFT) {
        hover_id = id
    }
    if focus_id == id {
        if rl.IsMouseButtonPressed(.LEFT) && !mouse_over {
            set_focus(event, 0)
        }
        if !hold_focus && !rl.IsMouseButtonDown(.LEFT) {
            set_focus(event, 0)
        }
        if rl.IsMouseButtonReleased(.LEFT) && mouse_over {
            clicked_id = id
        }
    }
    if hover_id == id {
        if rl.IsMouseButtonPressed(.LEFT) {
            set_focus(event, id)
        } else if !mouse_over {
            hover_id = 0
        }
    }
}

create_button :: proc(id: GuiId, rect: rl.Rectangle, color: rl.Color, text: string) -> Button {
    return Button{
        id      = id,
        rect    = rect,
        origin  = rl.Vector2{rect.width * .5, rect.height * .5},
        color   = color,
        text    = text,
        clicked = false,
    }
}

update_button :: proc(using button: ^Button, event: ^EventSystem) {
    corrected_rect := rect
    corrected_rect.x -= 100
    corrected_rect.y -= 25

    update_control(event, id, corrected_rect)
    if id == event.hover_id {
        color = {36, 150, 80, 255}
    }
    if id == event.focus_id {
        color = {36, 190, 90, 255}
    }
    if id == event.clicked_id {
        button.clicked = true
    } else {
        button.clicked = false
    }

    rl.DrawRectanglePro(rect, origin, 0, color)
    x := i32(corrected_rect.x + rect.width*.15)
    y := i32(corrected_rect.y + rect.height*.3)
    rl.DrawText(rl.TextFormat("%s", text), x, y, 24, rl.WHITE)
}

restart_game :: proc(using game: ^Game) {
    state = .GAMEPLAY
    turn_state = .PLAYER
    player_state = .FIRST_CARD
    clear(&player_card)
    clear(&opponent_card)
    clear(&ai_memory)
    clear(&deck)

    make_card_deck(&deck)
    for &card, i in game.deck {
        card.pos.x = cw*.7 + f32(i%GRID_WIDTH) * cw*1.05
        card.pos.y = ch*.7 + f32(i/GRID_WIDTH) * ch*1.05
    }
}

cw :: f32(CARD_WIDTH) * .8
ch :: f32(CARD_HEIGHT) * .8

main :: proc()
{
    rl.SetTraceLogLevel(.ERROR)
    rl.InitWindow(WIDTH, HEIGHT, "Game")
    defer rl.CloseWindow()

    card_texture := rl.LoadTexture("data/playingCards.png")
    defer rl.UnloadTexture(card_texture)
    cardback_texture := rl.LoadTexture("data/playingCardBacks.png")
    defer rl.UnloadTexture(cardback_texture)

    n := (GRID_WIDTH * GRID_HEIGHT) / 2
    game: Game
    game.state = .MENU
    game.turn_state = .PLAYER
    game.player_state = .FIRST_CARD
    game.deck = make([dynamic]Card); make_card_deck(&game.deck);
    game.player_card = make([dynamic]u32)
    game.opponent_card = make([dynamic]u32)
    game.ai_memory = make([dynamic]u32)
    defer delete(game.player_card)
    defer delete(game.opponent_card)
    defer delete(game.deck)
    defer delete(game.ai_memory)

    event: EventSystem

    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose()
    {
        free_all(context.temp_allocator)

        event.mouse_pos = rl.GetMousePosition()
        game.dt = rl.GetFrameTime()

        sw := f32(rl.GetScreenWidth())
        sh := f32(rl.GetScreenHeight())

        if game.state == .GAMEPLAY {
            if len(game.player_card) + len(game.opponent_card) == n {
                if game.player_point > game.ai_point {
                    game.state = .WIN
                } else if game.player_point < game.ai_point {
                    game.state = .LOOSE
                } else {
                    game.state = .DRAW
                }
            }
        }

        for &card, i in game.deck {
            //animate position
            if card.pos != card.v_pos && card.t < 1 {
                card.v_pos += card.t*(card.pos - card.v_pos);
                card.t += game.dt;
            } else {
                card.t = 0
            }

            if card.state == .COLLECTED {
                continue
            }
            origin := rl.Vector2{cw*0.5, ch*0.5}
            rect := rl.Rectangle{card.pos.x, card.pos.y, cw, ch}
            rect.x -= origin.x
            rect.y -= origin.y

            if game.state == .GAMEPLAY &&  game.turn_state == .PLAYER {
                id := GuiId(uintptr(&card))
                update_control(&event, id, rect)

                if event.hover_id == id {
                    card.tint = {255, 250, 150, 255}
                } else {
                    card.tint = rl.WHITE
                }
                if event.focus_id == id {
                    #partial switch game.player_state {
                    case .FIRST_CARD:
                        game.first_id = u32(i)
                        game.player_state = .SECOND_CARD
                    case .SECOND_CARD:
                        if u32(i) != game.first_id {
                            game.second_id = u32(i)
                            game.check_timer = 0
                            game.player_state = .CHECK_CARD
                        }
                    }
                    card.state = .SHOW
                }
            }
        }

        if game.state == .GAMEPLAY && game.player_state == .CHECK_CARD {
            game.check_timer += game.dt
            if game.check_timer > .5 {
                if game.deck[game.first_id].value == game.deck[game.second_id].value &&
                game.deck[game.first_id].suit == game.deck[game.second_id].suit {
                    game.deck[game.first_id].state = .COLLECTED
                    game.deck[game.second_id].state = .COLLECTED
                    switch game.turn_state {
                        case .PLAYER:
                            append(&game.player_card, game.first_id)
                        case .AI:
                            append(&game.opponent_card, game.first_id)
                    }
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

        if game.state == .GAMEPLAY && game.turn_state == .AI {
            #partial switch game.player_state {
                case .FIRST_CARD:
                    if game.ai_timer > .5 {
                        rand_id := rand.uint32() % u32(len(game.deck))

                        if game.deck[rand_id].state != .COLLECTED {
                            add_distinct_memory(&game.ai_memory, rand_id)

                            game.first_id = rand_id
                            game.deck[game.first_id].state = .SELECTED
                            game.deck[game.first_id].tint = {100, 100, 200, 255}
                            game.player_state = .SECOND_CARD
                            game.ai_timer = 0
                        }
                    } else {
                        game.ai_timer += game.dt
                    }
                case .SECOND_CARD:
                    if game.ai_timer > .5 {
                        id, got_match := check_memory(&game.ai_memory, &game.deck, game.first_id)
                        if !got_match {
                            id = rand.uint32() % u32(len(game.deck))
                        }
                        if id != game.first_id && game.deck[id].state != .COLLECTED {
                            if !got_match {
                                add_distinct_memory(&game.ai_memory, id)
                            }
                            game.second_id = id
                            game.deck[game.second_id].state = .SELECTED
                            game.deck[game.second_id].tint = {100, 100, 200, 255}
                            game.check_timer = 0
                            game.player_state = .CHECK_CARD
                            game.ai_timer = 0
                        }
                    } else {
                        game.ai_timer += game.dt
                    }
            }
        }

        {// game drawing stuff
        rl.BeginDrawing();
        rl.ClearBackground({36, 100, 50, 255})
        origin := rl.Vector2{cw*0.5, ch*0.5}
        for card in game.deck {
            if card.state == .COLLECTED {
                continue
            }
            src := rl.Rectangle{
                card_subtexture[card.id].x * CARD_WIDTH,
                card_subtexture[card.id].y * CARD_HEIGHT,
                CARD_WIDTH, CARD_HEIGHT
            }
            rect := rl.Rectangle{card.v_pos.x, card.v_pos.y, cw, ch}

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

        if game.state != .MENU {// Draw Player Cards and Points
            FONT_SIZE :: 30
            x := f32(GRID_WIDTH*cw) + cw*1.5
            point_x := i32(x)
            y := sh - ch*1.2
            game.player_point = 0
            for card_id in game.player_card {
                card := game.deck[card_id]
                x += cw*.3;
                game.player_point += card_value(card)
                src := rl.Rectangle{
                    card_subtexture[card.id].x * CARD_WIDTH,
                    card_subtexture[card.id].y * CARD_HEIGHT,
                    CARD_WIDTH, CARD_HEIGHT
                }
                rect := rl.Rectangle{x, y, cw, ch}
                tint := rl.WHITE

                rl.DrawTexturePro(card_texture, src, rect, origin, 0, tint)
            }
            rl.DrawText(rl.TextFormat("Player : %d", game.player_point),
                        i32(point_x), i32(y-ch*.8), FONT_SIZE, rl.WHITE)

            game.ai_point = 0
            x = f32(GRID_WIDTH*cw) + cw*1.5
            y = ch*1.2
            for card_id in game.opponent_card {
                card := game.deck[card_id]
                game.ai_point += card_value(card)
                x += cw*.3
                src := rl.Rectangle{
                    card_subtexture[card.id].x * CARD_WIDTH,
                    card_subtexture[card.id].y * CARD_HEIGHT,
                    CARD_WIDTH, CARD_HEIGHT
                }
                rect := rl.Rectangle{x, y, cw, ch}
                tint := rl.WHITE

                rl.DrawTexturePro(card_texture, src, rect, origin, 0, tint)
            }
            rl.DrawText(rl.TextFormat("Opponent : %d", game.ai_point),
                        i32(point_x), i32(y+ch*.6), FONT_SIZE, rl.WHITE)
        }

        switch game.state {
            case .MENU:
                rect := rl.Rectangle{sw*.7, sh*.5, 200, 50}
                color := rl.Color{36, 125, 50, 255}
                start_button := create_button(1, rect, color, "Start Game")
                update_button(&start_button, &event)
                if start_button.clicked {
                    game.state = .GAMEPLAY

                    for &card, i in game.deck {
                        card.pos.x = cw*.7 + f32(i%GRID_WIDTH) * cw*1.05
                        card.pos.y = ch*.7 + f32(i/GRID_WIDTH) * ch*1.05
                    }
                }
            case .GAMEPLAY:
                rl.DrawText(rl.TextFormat("Turn : %s", game.turn_state), i32(sw*.6), 20, 28, rl.WHITE)
            case .WIN:
                rect := rl.Rectangle{sw*.7, sh*.5, 200, 50}
                color := rl.Color{36, 125, 50, 255}
                restart_button := create_button(1, rect, color, "Restart")
                update_button(&restart_button, &event)
                if restart_button.clicked {
                    restart_game(&game);
                }
                rl.DrawText("You Won!", i32(sw*.4), 20, 28, rl.WHITE)
            case .LOOSE:
                rect := rl.Rectangle{sw*.7, sh*.5, 200, 50}
                color := rl.Color{36, 125, 50, 255}
                restart_button := create_button(1, rect, color, "Restart")
                update_button(&restart_button, &event)
                if restart_button.clicked {
                    restart_game(&game);
                }
                rl.DrawText("You Loose!", i32(sw*.4), 20, 28, rl.WHITE)
            case .DRAW:
                rect := rl.Rectangle{sw*.7, sh*.5, 200, 50}
                color := rl.Color{36, 125, 50, 255}
                restart_button := create_button(1, rect, color, "Restart")
                update_button(&restart_button, &event)
                if restart_button.clicked {
                    restart_game(&game);
                }
                rl.DrawText("Match Draw", i32(sw*.4), 20, 28, rl.WHITE)
        }

        rl.DrawFPS(10, 10);
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
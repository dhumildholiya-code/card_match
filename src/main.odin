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
DECK_SIZE   :: GRID_WIDTH * GRID_HEIGHT

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
    COLLECTED,
}

Card :: struct {
    id      : u32,
    suit    : CardSuit,
    value   : CardValue,
    state   : CardState,
    pos     : rl.Vector2,
    tint    : rl.Color,
    tween   : Tween,
}

Tween :: struct {
    start_pos   : rl.Vector2,
    end_pos     : rl.Vector2,
    time        : f32,
    duration    : f32,
    elapsed     : f32,
    running     : bool,
    started     : bool,
}

Score :: struct {
    value       : int,
    ui_value    : int,
    timer       : f32,
    running     : bool,
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
    deck            : []Card,
    player_card     : [dynamic]u32,
    opponent_card   : [dynamic]u32,
    player_score    : Score,
    ai_score        : Score,
    ai_memory       : [dynamic]u32,

    dt              : f32,
    check_timer     : f32,
    ai_timer        : f32,
    first_id        : u32,
    second_id       : u32,
}

Point :: struct {
    pos: rl.Vector2,
    old_pos: rl.Vector2,
}

sign :: proc(x: f32) -> f32 {
    if x >= 0 { return 1 } else {return -1}
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

make_card_deck :: proc(deck: ^[]Card) {
    n := (GRID_WIDTH * GRID_HEIGHT) / 2
    all_cards := make([]u32, MAX_CARDS, context.temp_allocator)
    for i in 0..<MAX_CARDS {
        all_cards[i] = u32(i)
    }
    rand.shuffle(all_cards[:])

    j := 0
    for i in 0..<n {
        id := all_cards[i]
        deck[j] = make_card(id)
        j+=1
        deck[j] = make_card(id)
        j+=1
    }
    rand.shuffle(deck[:])

    sh := f32(rl.GetScreenHeight())
    sw := f32(rl.GetScreenWidth())
    for &card in deck {
        card.pos.x = sw*.4
        card.pos.y = sh*.5
    }
}

collect_card :: proc(using game: ^Game) {
    deck[first_id].state = .COLLECTED
    deck[second_id].state = .COLLECTED
    deck[first_id].tint = rl.WHITE
    deck[second_id].tint = rl.WHITE

    switch turn_state {
    case .PLAYER:
        append(&player_card, first_id)
        add_score(&player_score, card_value(deck[first_id]))
    case .AI:
        append(&opponent_card, first_id)
        add_score(&ai_score, card_value(deck[first_id]))
    }

    //update collected card position
    x := f32(GRID_WIDTH*cw) + cw*1.5
    sh := f32(rl.GetScreenHeight())
    for card_id, i in game.player_card {
        target: rl.Vector2
        target.x = x + cw*.3 * f32(i)
        target.y = sh - ch*1.2
        set_tween(&game.deck[card_id], target, .3, f32(rl.GetTime()))
    }

    for card_id, i in game.opponent_card {
        target: rl.Vector2
        target.x = x + cw*.3 * f32(i)
        target.y = ch*1.2
        set_tween(&game.deck[card_id], target, .3, f32(rl.GetTime()))
    }
}

set_tween :: proc(card: ^Card, end_pos: rl.Vector2, duration: f32, start_time: f32) {
    card.tween.start_pos = card.pos
    card.tween.end_pos = end_pos
    card.tween.duration = duration
    card.tween.time = start_time
    card.tween.running = true
    card.tween.started = false
}

add_score :: proc(using score: ^Score, new_value: int) {
    value += new_value
    timer = 0
    running = true
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

check_memory :: proc(memory: ^[dynamic]u32, deck: ^[]Card, check_id: u32) -> (id: u32, matched: bool) {
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
    FONT_SIZE :: 24
    c_text := rl.TextFormat("%s", text)
    text_width := f32(rl.MeasureText(c_text, FONT_SIZE))
    x := i32(corrected_rect.x + rect.width*.5 - text_width*.5)
    y := i32(corrected_rect.y + rect.height*.5 - f32(FONT_SIZE)*.4)
    rl.DrawText(c_text, x, y, FONT_SIZE, rl.WHITE)
}

update_score :: proc(using score: ^Score, dt: f32) {
    if running {
        if value != ui_value {
            timer += dt
            if timer >= .05 {
                ui_value += 1
                timer = 0
            }
        } else {
            running = false
        }
    }
}

restart_game :: proc(using game: ^Game) {
    state = .GAMEPLAY
    turn_state = .PLAYER
    player_state = .FIRST_CARD
    player_score = {0,0,0,false}
    ai_score = {0,0,0,false}
    clear(&player_card)
    clear(&opponent_card)
    clear(&ai_memory)

    make_card_deck(&deck)
    for &card, i in game.deck {
        target: rl.Vector2
        target.x = cw*.7 + f32(i%GRID_WIDTH) * cw*1.05
        target.y = ch*.7 + f32(i/GRID_WIDTH) * ch*1.05
        set_tween(&card, target, .2, f32(rl.GetTime()) + f32(i)*.05)
    }
}

cw :: f32(CARD_WIDTH) * .8
ch :: f32(CARD_HEIGHT) * .8

main :: proc()
{
    rl.SetTraceLogLevel(.ERROR)
    rl.InitWindow(WIDTH, HEIGHT, "Game")
    defer rl.CloseWindow()
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()
    rl.SetTargetFPS(60)

    card_texture := rl.LoadTexture("data/playingCards.png")
    defer rl.UnloadTexture(card_texture)
    cardback_texture := rl.LoadTexture("data/playingCardBacks.png")
    defer rl.UnloadTexture(cardback_texture)
    //setup sounds
    card_place_sound := rl.LoadSound("data/card-place-2.wav")
    defer rl.UnloadSound(card_place_sound)
    card_flip_sound := rl.LoadSound("data/card-place-1.wav")
    defer rl.UnloadSound(card_flip_sound)
    rl.SetSoundVolume(card_place_sound, .8)
    rl.SetSoundVolume(card_flip_sound, .8)

    n := (GRID_WIDTH * GRID_HEIGHT) / 2
    game: Game
    game.state = .MENU
    game.turn_state = .PLAYER
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

    sw := f32(rl.GetScreenWidth())
    sh := f32(rl.GetScreenHeight())

    event: EventSystem

    for !rl.WindowShouldClose()
    {
        free_all(context.temp_allocator)

        event.mouse_pos = rl.GetMousePosition()
        game.dt = rl.GetFrameTime()
        time := f32(rl.GetTime())

        sw = f32(rl.GetScreenWidth())
        sh = f32(rl.GetScreenHeight())

        if game.state == .GAMEPLAY {
            if len(game.player_card) + len(game.opponent_card) == n {
                if game.player_score.value > game.ai_score.value {
                    game.state = .WIN
                } else if game.player_score.value < game.ai_score.value {
                    game.state = .LOOSE
                } else {
                    game.state = .DRAW
                }
            }
        }

        update_score(&game.player_score, game.dt)
        update_score(&game.ai_score, game.dt)

        for &card, i in game.deck {
            { // card tween logic
                if card.tween.running && card.tween.time <= time {
                    card.tween.elapsed = time - card.tween.time
                    t := card.tween.elapsed / card.tween.duration
                    if !card.tween.started {
                        card.tween.started = true
                        if i & 1 == 1 {//NOTE: Play sound every other card
                            rl.SetSoundPitch(card_place_sound, .5 + f32(i)*.02)
                            rl.PlaySound(card_place_sound)
                        }
                    }
                    if t <= 1 {
                        card.pos = card.tween.start_pos + t*(card.tween.end_pos - card.tween.start_pos);
                    } else {
                        card.pos = card.tween.end_pos;
                        card.tween.running = false
                    }
                }
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
                        rl.SetSoundPitch(card_flip_sound, rand.float32_range(.7,1.1))
                        rl.PlaySound(card_flip_sound)
                    case .SECOND_CARD:
                        if u32(i) != game.first_id {
                            game.second_id = u32(i)
                            game.check_timer = 0
                            game.player_state = .CHECK_CARD
                            rl.SetSoundPitch(card_flip_sound, rand.float32_range(.7,1.1))
                            rl.PlaySound(card_flip_sound)
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
                            rl.SetSoundPitch(card_flip_sound, rand.float32_range(.7,1.1))
                            rl.PlaySound(card_flip_sound)
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
                            rl.SetSoundPitch(card_flip_sound, rand.float32_range(.7,1.1))
                            rl.PlaySound(card_flip_sound)
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

        if game.state != .MENU {// Draw Points
            FONT_SIZE :: 30
            bg_rect: rl.Rectangle
            bg_rect.width = 500
            bg_rect.height = ch + 80
            bg_rect.x = f32(GRID_WIDTH*cw + cw*.7)
            bg_rect.y = f32(sh*.5 + ch*.3)
            rl.DrawRectangleRec(bg_rect, {30, 30, 30, 70})
            for card_id in game.player_card {
                card := game.deck[card_id]
                src := rl.Rectangle{
                    card_subtexture[card.id].x * CARD_WIDTH,
                    card_subtexture[card.id].y * CARD_HEIGHT,
                    CARD_WIDTH, CARD_HEIGHT
                }
                rect := rl.Rectangle{card.pos.x, card.pos.y, cw, ch}
                rl.DrawTexturePro(card_texture, src, rect, origin, 0, card.tint)
            }
            rl.DrawText(rl.TextFormat("Player : %d", game.player_score.ui_value),
                        i32(bg_rect.x+20), i32(bg_rect.y+15),
                        FONT_SIZE, rl.WHITE)

            bg_rect.y = f32(sh*.5 - ch*.3 - bg_rect.height)
            rl.DrawRectangleRec(bg_rect, {30, 30, 30, 70})
            for card_id in game.opponent_card {
                card := game.deck[card_id]
                src := rl.Rectangle{
                    card_subtexture[card.id].x * CARD_WIDTH,
                    card_subtexture[card.id].y * CARD_HEIGHT,
                    CARD_WIDTH, CARD_HEIGHT
                }
                rect := rl.Rectangle{card.pos.x, card.pos.y, cw, ch}
                rl.DrawTexturePro(card_texture, src, rect, origin, 0, card.tint)
            }
            rl.DrawText(rl.TextFormat("Opponent : %d", game.ai_score.ui_value),
                        i32(bg_rect.x+20), i32(bg_rect.y+bg_rect.height-FONT_SIZE-10),
                        FONT_SIZE, rl.WHITE)
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
                        target: rl.Vector2
                        target.x = cw*.7 + f32(i%GRID_WIDTH) * cw*1.05
                        target.y = ch*.7 + f32(i/GRID_WIDTH) * ch*1.05
                        set_tween(&card, target, .2, time + f32(i)*.05)
                    }
                }
            case .GAMEPLAY:
                rl.DrawText(rl.TextFormat("Turn : %s", game.turn_state), i32(sw*.6), 35, 28, rl.WHITE)
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
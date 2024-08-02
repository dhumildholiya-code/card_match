package game

import "core:math/rand"
import rl "vendor:raylib"

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


player_input :: proc(using game: ^Game, event: ^EventSystem, using assets: ^Asset) {
    for &card, i in deck {
        if card.state == .COLLECTED { continue }

        origin := rl.Vector2{cw*0.5, ch*0.5}
        rect := rl.Rectangle{card.pos.x, card.pos.y, cw, ch}
        rect.x -= origin.x
        rect.y -= origin.y
        id := GuiId(uintptr(&card))
        update_control(event, id, rect)

        if event.hover_id == id {
            card.tint = {255, 250, 150, 255}
        } else {
            card.tint = rl.WHITE
        }
        if event.focus_id == id {
            #partial switch player_state {
                case .FIRST_CARD:
                first_id = u32(i)
                player_state = .SECOND_CARD
                rl.SetSoundPitch(card_flip_sound, rand.float32_range(.7,1.1))
                rl.PlaySound(card_flip_sound)
                case .SECOND_CARD:
                if u32(i) != first_id {
                    second_id = u32(i)
                    check_timer = 0
                    player_state = .CHECK_CARD
                    rl.SetSoundPitch(card_flip_sound, rand.float32_range(.7,1.1))
                    rl.PlaySound(card_flip_sound)
                }
            }
            card.state = .SHOW
        }
    }
}

ai_update :: proc(using game: ^Game, using assets: ^Asset) {
    #partial switch player_state {
    case .FIRST_CARD:
        if ai_timer > .5 {
            rand_id := rand.uint32() % u32(len(deck))

            if deck[rand_id].state != .COLLECTED {
                add_distinct_memory(&ai_memory, rand_id)

                first_id = rand_id
                deck[first_id].state = .SELECTED
                deck[first_id].tint = {100, 100, 200, 255}
                player_state = .SECOND_CARD
                ai_timer = 0
                rl.SetSoundPitch(card_flip_sound, rand.float32_range(.7,1.1))
                rl.PlaySound(card_flip_sound)
            }
        } else {
            ai_timer += dt
        }
    case .SECOND_CARD:
        if ai_timer > .5 {
            id, got_match := check_memory(&ai_memory, &deck, first_id)
            if !got_match {
                id = rand.uint32() % u32(len(deck))
            }
            if id != first_id && deck[id].state != .COLLECTED {
                if !got_match {
                    add_distinct_memory(&ai_memory, id)
                }
                second_id = id
                deck[second_id].state = .SELECTED
                deck[second_id].tint = {100, 100, 200, 255}
                check_timer = 0
                player_state = .CHECK_CARD
                ai_timer = 0
                rl.SetSoundPitch(card_flip_sound, rand.float32_range(.7,1.1))
                rl.PlaySound(card_flip_sound)
            }
        } else {
            ai_timer += dt
        }
    }
}

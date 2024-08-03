package game

import "core:math/rand"
import "core:math"
import rl "vendor:raylib"

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
    x := GRID_WIDTH*cw
    for &card in deck {
        card.pos.x = x + (sw-x)*.3
        card.pos.y = sh*.4
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

update_cards :: proc(using game: ^Game, using assets: ^Asset, time: f32) {
    for &card, i in deck {
        if card.tween.running && card.tween.time <= time {
            card.tween.elapsed = time - card.tween.time
            t := card.tween.elapsed / card.tween.duration
            if !card.tween.started {
                card.tween.started = true
                if i & 1 == 1 { //NOTE(Dhumil): Play sound every other card
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
}

set_card_win_pos :: proc(deck: ^[]Card, cards: ^[dynamic]u32) {
    x :: f32(GRID_WIDTH*cw)
    sh := f32(rl.GetScreenHeight())
    w := x*.8
    space := w/f32(len(cards))
    for card_id, i in cards {
        target: rl.Vector2
        target.x = x*.2 + space * f32(i)
        target.y = sh*.5
        set_tween(&deck[card_id], target, .5, f32(rl.GetTime()))
    }
}

card_win_effect :: proc(deck: ^[]Card, cards: ^[dynamic]u32, speed: f32) {
    sh := f32(rl.GetScreenHeight())
    for card_id, i in cards {
        card := &deck[card_id]
        card.pos.y = 100*math.sin(f32(rl.GetTime())*speed + f32(i)*.3) + sh*.5
    }
}


local Queue = require('queue')
local Animation = require('animation')

function build_deck()
    local deck = {}

	for i, suit in ipairs({'hearts', 'spades', 'diamonds', 'clubs'}) do
		for rank = 1, 13 do
            local image = rank + (13 * (i - 1))

			table.insert(deck, {
                suit   = suit,
                rank   = rank,
                image  = image,
            })
		end
	end

    return deck
end

function calc_value(rank)
    -- Normal cards
    local card_value = rank

    -- Face cards
    if rank > 10 then
        card_value = 10
    end

    return card_value
end

function hand_value(hand)
    local total = 0
    local card_value = 0

    local has_ace = false

    for _, card in ipairs(hand) do
        card_value = calc_value(card.rank)

        -- We have an Ace
        if card.rank == 1 then
            has_ace = true
        end

        total = total + card_value
    end

    if has_ace and total <= 11 then
        total = total + 10
    end

    return total
end

function bust(hand_score, rules)
    return hand_score > rules.score_thresh
end

function twenty_one(hand_score, rules)
    return hand_score == rules.score_thresh
end

function check_win(player, dealer, rules)
    local player_score = hand_value(player)
    local dealer_score = hand_value(dealer)

    if bust(player_score, rules) then
        return 'dealer'
    end

    if bust(dealer_score, rules) then
        return 'player'
    end

    if twenty_one(player_score, rules) then
        return 'player'
    end

    if twenty_one(dealer_score, rules) then
        return 'dealer'
    end

    if player_score > dealer_score then
        return 'player'
    elseif dealer_score > player_score then
        return 'dealer'
    else
        return 'draw'
    end
end

function in_rect(px, py, x, y, w, h)
    return px >= x and px <= x + w
       and py >= y and py <= y + h
end

function draw_card(deck, hand)
    table.insert(hand,
        table.remove(deck, love.math.random(#deck)))
end

function print_text_shadow(text, x, y)
    love.graphics.setColor(0,0,0)
    love.graphics.print(text, x+2, y+2)
    love.graphics.setColor(1,1,1)
    love.graphics.print(text, x, y)
end

-- function that counts up every time its called
local __c=0
function iota()
    __c = __c + 1
    return __c
end

local Game = {
    -- Game loaded resources, textures, music, images...
    resources = {
        images = {
            deck_back  = nil,
            cards      = {},
            characters = {},
        },

        fonts = {
        },
    },

    const = {
        -- This is NOT the same as deck size,
        -- just means the number of ranks,suits,specials etc
        -- that have different images.
        --
        -- general deckbuilding just adds repeated cards
        -- over and over.
        CARDS = 52,

        CARD_W = 52,
        CARD_H = 72,

        events = {
            DEALER_AUTOHIT = iota(),
            PLAYER_HIT     = iota(),
            SCORE_UPDATE   = iota(),
            ROUND_END      = iota(),
            GAME_RESET     = iota(),
            CHECK_WIN      = iota(),
            REVEAL_CARDS   = iota(),
        },
    },

    deltatime = 0,

    -- General state of the game, the deck, and the round-specific state
    -- e.g. hands.
    state = {
        -- We draw from the same deck every round
        -- and only rebuild once we run out of cards
        deck = {},

        -- state for a specific round of the game (only game LOGIC states)
        round = {
            -- Player and dealer's hands
            hands = {
                player = {},
                dealer = {},
            },

            flags = {
                -- Used thttps://azuna-pixels.itch.io/free-food-iconso block player hits
                player_can_hit = true,

                -- Stays nil until game has a defined winner
                winner = nil,
            },

            dealer = {
                name = 'Opponent',
            },
        },

        view = {
            display_name = {
                dealer = 'Opponent',
                player = 'Player',
            },

            hands = {
                dealer = {},
                player = {},
            },

            deck = {},

            ui = {
                dealer = {
                    focus_bar = {},
                    animation = {},
                }
            },
        },

        -- Still deciding on a more general approach for
        -- events or have a separate queue for rounds
        events = Queue.new(),
    },

    -- Game settings, such as max score and graphical adjustments
    settings = {
        gameplay = {
            -- max game score
            score_thresh     = 21,
            dealer_score_min = 17, -- minimum score that the dealer has to hit
        },

        -- Graphical settings
        --  * deck_margin_x     Separation between the deck and the left screen corner
        --
        --  * card_margin_x     Separation between the dealer/player cards and the left screen corner
        --  * card_spacing_x    Card width + gap between them
        --
        --  * card_margin_y             Separation between the dealer/player and the top of the screen
        --  * card_spacing_y            Card height + vertical gap between them (currently this gap is 0)
        --  * card_margin_players_y     Separation between the dealer and player cards (Vertical)
        graphical = {
            deck_margin_x = 20,
            deck_margin_y = 40,

            card_margin_x = 150,
            card_spacing_x = 60,

            card_margin_y = 30,
            card_spacing_y = 82,
            card_margin_players_y = 40,
        },
    },
}

function Game:load_images()
    local images = self.resources.images

    table.insert(images.characters,
        love.graphics.newImage('images/characters/witch/c00b_01idle.png'))

    -- Load the deck's back image
    images.deck_back = love.graphics.newImage('images/decks/red.png')

    -- Load cards, named 01.png through 52.png under images/
    for card = 1, Game.const.CARDS do
        local path = string.format('images/%02d.png', card)
        images.cards[card] = love.graphics.newImage(path)
    end
end

function Game:load_fonts()
    --local monogram = love.graphics.newFont("resources/fonts/monogram.ttf", 20)
    local badcomic = love.graphics.newFont("resources/fonts/badcomic/ttf/BadComic-Regular.ttf", 14)
    local kaph     = love.graphics.newFont("resources/fonts/kaph/ttf/Kaph-Regular.ttf", 16)

    self.resources.fonts.main = badcomic
    self.resources.fonts.head = kaph

    love.graphics.setFont(badcomic)
end

function Game:enqueue(e)
    Queue.push(self.state.events, e)
end

-- Repetition here is intentional, i want event handling to be as clear
-- and simple as possible, since it's the backbone of the engine.
-- Also, as you see below, sometimes we need to add restrictions, and
-- functions make this easier.
function Game:request_dealer_autohit()
    if #self.state.deck < 1 then return end

    self:enqueue(self.const.events.DEALER_AUTOHIT)
end

function Game:request_player_hit()
    if not self.state.round.flags.player_can_hit then return end

    self:enqueue(self.const.events.PLAYER_HIT)
end

function Game:request_score_update()
    self:enqueue(self.const.events.SCORE_UPDATE)
end

function Game:request_game_reset()
    self:enqueue(self.const.events.GAME_RESET)
end

function Game:request_round_end()
    self:enqueue(self.const.events.ROUND_END)
end

function Game:request_check_win()
    self:enqueue(self.const.events.CHECK_WIN)
end

function Game:request_reveal_cards()
    self:enqueue(self.const.events.REVEAL_CARDS)
end
-- ===================================================

function Game:build_deck()
    self.state.deck = build_deck()
end

function Game:hand_update_view(player)
    local index = #self.state.round.hands[player]
    local graphics = self.settings.graphical

    local x = graphics.card_margin_x + (index - 1) * graphics.card_spacing_x
    local y = graphics.card_margin_y

    if player == 'player' then
        y = y + (graphics.card_spacing_y + graphics.card_margin_players_y)
    end

    self.state.view.hands[player][index] = {
        x = x,
        y = y,
        target_x = x,
        target_y = y,

        lift = 0,
        scale = 1,
        hover = false,

        alpha = 0,
        target_alpha = 1,
    }
end

function Game:deck_update_view()
    local graphics = self.settings.graphical

    local margin_x = graphics.deck_margin_x + (self.const.CARDS/4)
    local margin_y = graphics.deck_margin_y + (self.const.CARDS/10)

    local deck = self.state.view.deck

    -- Stuff that we don't bother changing
    local lift  = deck.lift
    local hover = deck.hover
    local scale = deck.scale

    self.state.view.deck = {
        text_x = graphics.deck_margin_x + (graphics.card_spacing_x * 0.35),
        text_y = graphics.deck_margin_y + graphics.card_spacing_y + 5,

        x = margin_x,
        y = margin_y,
        
        x_div = 5,
        y_div = 10,

        lift  = lift,
        hover = hover,
        scale = scale,
    }
end

function Game:draw_for(player)
    draw_card(self.state.deck, self.state.round.hands[player])

    self:hand_update_view(player)
    self:deck_update_view()

    self:request_score_update()
end

function Game:hand_value(player)
    return hand_value(self.state.round.hands[player])
end

function Game:hide_cards(player, mask)
    if #self.state.view.hands[player] < #mask then
        error("Too many cards specified in hide mask")
    end

    for index, hidden in ipairs(mask) do
        self.state.view.hands[player][index].hidden = hidden
    end
end

function Game:show_cards()
    self:hide_cards('player', { false, false })
    self:hide_cards('dealer', { false, false })
end

function Game:reset()
    self.state.round.flags.winner = nil
    self.state.events = Queue.new()

    -- TODO: make hand size configurable
    if #self.state.deck < 4 then
        self:build_deck()
    end

	self.state.round.hands = {
        player = {},
        dealer = {},
    }

    -- Define opponent here
    self.state.round.dealer = {
        name = "Opponent",
        
        focus     = 0,
        focus_max = 8,
    }

    self.state.view.ui.dealer = {
        focus_bar = {
            x = 150,
            y = 10,
        },

        animation = Animation.new(
                self.resources.images.characters[
                    love.math.random(#self.resources.images.characters)],
               480, 480, 14)
    }

    self.state.view.ui.dealer.animation.playing = true

    self.state.view.hands = {
        player = {},
        dealer = {},
    }

    self.state.view.deck = {
        lift = 0,
        hover = 0,
        scale = 1,
    }

    self.state.round.flags.player_can_hit = true

    -- Drawing cards
    self:draw_for('player')
    self:draw_for('player')

    self:draw_for('dealer')
    self:draw_for('dealer')
    
    self:hide_cards('player', { false, false })
    self:hide_cards('dealer', { true, false })
end

function Game:print_overlay()
    local graphics = self.settings.graphical

    love.graphics.setColor(0.2,0.2,0.2)

    love.graphics.rectangle("fill", 15, 30, 110, 200)

    love.graphics.setColor(0.4,0.4,0.4)

    love.graphics.rectangle("fill", 5, 15, 110, 200)

    love.graphics.setColor(1,1,1)
end

function Game:print_dealer_character()
    Animation.draw(
        self.state.view.ui.dealer.animation,
        300, 10)
end

function Game:print_cards(player)
    local hand = self.state.round.hands[player]

    local has_hidden_card = false

    local x = 0
    local y = 0

    for index, card in ipairs(hand) do
        local view = self.state.view.hands[player][index]

        x = view.x
        y = view.y + view.lift

        local r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(1, 1, 1, view.alpha)

        if view.hidden then
            has_hidden_card = true

            love.graphics.draw(
                self.resources.images.deck_back, x, y)
        else
            love.graphics.draw(
                self.resources.images.cards[card.image], x, y)
        end

        love.graphics.setColor(r, g, b, a)
    end

    love.graphics.setColor(0,0,0)

    -- hand totals
    y = y - 20

    if has_hidden_card then
        love.graphics.print('total: ?', x, y)
    else
        love.graphics.print('total: '..hand_value(hand), x, y)
    end

    love.graphics.setColor(1,1,1)
end

function Game:print_deck()
    local deck = self.state.view.deck

    local text_x = deck.text_x
    local text_y = deck.text_y

    local x = deck.x
    local y = deck.y

    local x_div = deck.x_div
    local y_div = deck.y_div

    print_text_shadow(#self.state.deck..'/52', text_x, text_y)

    local deck_size = #self.state.deck

    for i = 1, deck_size do
        local draw_x = (-i/x_div) + x
        local draw_y = (-i/y_div) + y

        if i == deck_size then
            draw_y = draw_y + deck.lift
        end

        love.graphics.draw(self.resources.images.deck_back, draw_x, draw_y)
    end

end

function Game:player_hit()
    self:draw_for('player')
end

function Game:dealer_autohit()
    local dealer_min = self.settings.gameplay.dealer_score_min

    while self:hand_value('dealer') < dealer_min do
        if #self.state.deck < 1 then return end

        self:draw_for('dealer')
    end
end

function Game:score_update()
    local hands = self.state.round.hands
    local rules = self.settings.gameplay

    local player = Game:hand_value('player')
    local dealer = Game:hand_value('dealer')

    -- Player wins/loses
    if bust(player, rules) or twenty_one(player, rules) then
        self:request_round_end()
    end

    -- Dealer wins/loses
    if bust(dealer, rules) or twenty_one(dealer, rules) then
        self:request_round_end()
    end
end

function Game:check_win()
    local winner = check_win(
        self.state.round.hands.player,
        self.state.round.hands.dealer,
        self.settings.gameplay)

    self.state.round.flags.winner = winner
end

function Game:round_end()
    self.state.round.flags.player_can_hit = false

    self:request_dealer_autohit()
    self:request_reveal_cards()
    self:request_check_win()
end

function Game:cards_hover_check()
    local mx, my = love.mouse.getPosition()

    for player, cards in pairs(self.state.view.hands) do
        for _, view in ipairs(cards) do
            local hover = in_rect(
                mx, my, view.x, view.y,
                self.const.CARD_W,
                self.const.CARD_H)

            view.hover = hover
        end
    end
end

function Game:deck_hover_check()
    if #self.state.deck < 1 then
        self.state.view.deck.hover = false
        return
    end

    local mx, my = love.mouse.getPosition()
    local deck = self.state.view.deck

    local hover = in_rect(mx, my, deck.x, deck.y,
                    self.const.CARD_W,
                    self.const.CARD_H)

    deck.hover = hover
end

function Game:cards_animation_process()
    for player, cards in pairs(self.state.view.hands) do
        for _, view in ipairs(cards) do
            -- Lift
            local target_lift = view.hover and -12 or 0
            view.lift = view.lift +
                (target_lift - view.lift) * 12 * self.deltatime

            -- Fade
            view.alpha = view.alpha +
                (view.target_alpha - view.alpha) * 8 * self.deltatime
        end
    end
end

function Game:deck_animation_process()
    local deck = self.state.view.deck

    local target_lift = deck.hover and -10 or 0
    deck.lift = deck.lift + (target_lift - deck.lift) * 6 * self.deltatime

    if deck.hover then
        cursor = love.mouse.getSystemCursor("hand")
        love.mouse.setCursor(cursor)
    else
        love.mouse.setCursor()
    end
end

function Game:dealer_animation_process()
    Animation.update(
        self.state.view.ui.dealer.animation,
        self.deltatime)
end

function Game:animations_process()
    self:cards_hover_check()
    self:cards_animation_process()

    self:deck_hover_check()
    self:deck_animation_process()

    self:dealer_animation_process()
end

function Game:process(dt)
    self.deltatime = dt

    -- Animations
    self:animations_process()

    -- Events:
    --  DEALER_AUTOHIT
    --  PLAYER_HIT
    --  SCORE_UPDATE
    --  ROUND_END
    --  GAME_RESET
    --  CHECK_WIN
    --  REVEAL_CARDS
 
    while not Queue.empty(self.state.events) do
        local event = Queue.pop(self.state.events)

        if event == self.const.events.PLAYER_HIT then
            self:player_hit()
        elseif event == self.const.events.SCORE_UPDATE then
            self:score_update()
        elseif event == self.const.events.ROUND_END then
            self:round_end()
        elseif event == self.const.events.DEALER_AUTOHIT then
            self:dealer_autohit()
        elseif event == self.const.events.REVEAL_CARDS then
            self:show_cards()
        elseif event == self.const.events.CHECK_WIN then
            self:check_win()
        elseif event == self.const.events.GAME_RESET then
            self:reset()
        end
    end

end

function Game:print_winner()
    local winner = self.state.round.flags.winner

    if winner then
    end
end

-- Love functions

function love.load()
    Game:load_images()
    Game:load_fonts()

    Game:reset()

    love.graphics.setBackgroundColor(1, 0.8, 0.6)
end

function love.draw()
    Game:print_overlay()
    Game:print_dealer_character()
    Game:print_cards('player')
    Game:print_cards('dealer')
    Game:print_deck()

    Game:print_winner()
end

function love.update(dt)

    Game:process(dt)

    -- no cards?
    if #Game.state.deck < 1 then
        Game:request_round_end()
    end
end

function love.keypressed(key)
    if key == 's' then
        Game:request_round_end()
    elseif key == 'r' then
        Game:request_game_reset()
    end
end

function love.mousepressed(mx, my, button)
    if button == 1 then
        if Game.state.view.deck.hover then
            Game:request_player_hit()
        end
    end
end


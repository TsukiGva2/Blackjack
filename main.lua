
Queue = require('queue')

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
        return {
            win = 'dealer',
            msg = 'Dealer wins (player bust)'
        }
    end

    if bust(dealer_score, rules) then
        return {
            win = 'player',
            msg = 'Player wins (dealer bust)'
        }
    end

    if twenty_one(player_score, rules) then
        return {
            win = 'player',
            msg = 'Player wins ('..rules.score_thresh..')'
        }
    end

    if twenty_one(dealer_score, rules) then
        return {
            win = 'dealer',
            msg = 'Dealer wins ('..rules.score_thresh..')'
        }
    end

    if player_score > dealer_score then
        return {
            win = 'player',
            msg = 'Player wins ('..player_score..' against '..dealer_score..')'
        }
    elseif dealer_score > player_score then
        return {
            win = 'dealer',
            msg = 'Dealer wins ('..dealer_score..' against '..player_score..')'
        }
    else
        return {
            win = 'no one',
            msg = 'Draw'
        }
    end
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
__c=0
function iota()
    __c = __c + 1
    return __c
end

Game = {
    -- Game loaded resources, textures, music, images...
    resources = {
        images = {
            deck_back = nil,
            cards     = {},
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

    -- General state of the game, the deck, and the round-specific state
    -- e.g. hands.
    state = {
        -- We draw from the same deck every round
        -- and only rebuild once we run out of cards
        deck = {},

        animations = {
        },

        -- state for a specific round of the game
        round = {
            -- Player and dealer's hands
            hands = {
                player = {},
                dealer = {},
            },

            flags = {
                -- Used to block player hits
                player_can_hit = true,

                -- Stays nil until game has a defined winner
                winner = nil,
                winmsg = "",

                -- Number of cards hidden per player.
                -- TODO: hide INDEX instead of number of cards
                cards_hidden = {
                    dealer = { false, false },
                    player = { false, false },
                },
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

    -- Load the deck's back image
    images.deck_back = love.graphics.newImage('images/decks/red.png')

    -- Load cards, named 01.png through 52.png under images/
    for card = 1, Game.const.CARDS do
        local path = string.format('images/%02d.png', card)
        images.cards[card] = love.graphics.newImage(path)
    end
end

function Game:enqueue(e)
    Queue.push(self.state.events, e)
end

function Game:request_dealer_autohit()
    self:enqueue(self.const.events.DEALER_AUTOHIT)
end

-- Repetition here is intentional, i want event handling to be as clear
-- and simple as possible, since it's the backbone of the engine.
-- Also, as you see below, sometimes we need to add restrictions, and
-- functions make this easier.
function Game:request_player_hit()
    if not Game.state.round.flags.player_can_hit then return end

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

function Game:draw_for(player)
    draw_card(self.state.deck, self.state.round.hands[player])
    self:request_score_update()
end

function Game:hand_value(player)
    return hand_value(self.state.round.hands[player])
end

function Game:show_cards()
    self.state.round.flags.cards_hidden = {
                    dealer = { false, false },
                    player = { false, false },
                }
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

    -- Maybe apply deck special effects here?
    self.state.round.flags.cards_hidden = {
        dealer = { true, false },
        player = { false, false },
    }

    self.state.round.flags.player_can_hit = true

    -- Drawing cards
    self:draw_for('player')
    self:draw_for('player')

    self:draw_for('dealer')
    self:draw_for('dealer')
end

function Game:print_cards(player)
    local graphics = self.settings.graphical

    local xoffset = 0
    local yoffset = 0

    if player == 'player' then
        yoffset = graphics.card_spacing_y +
            graphics.card_margin_y +
            graphics.card_margin_players_y
    else
        yoffset = graphics.card_margin_y
    end

    local hand = self.state.round.hands[player]
    local hidden = self.state.round.flags.cards_hidden[player]

    -- This flag determines if we are going to print a '?' in the total
    local has_hidden_card = false

    for index, card in ipairs(hand) do
        xoffset = graphics.card_margin_x +
            (index - 1) * graphics.card_spacing_x

        if hidden[index] then
            has_hidden_card = true

            love.graphics.draw(
                self.resources.images.deck_back, xoffset, yoffset)
        else
            love.graphics.draw(
                self.resources.images.cards[card.image],
                xoffset, yoffset)
        end
    end

    love.graphics.setColor(0,0,0)

    -- hand totals
    yoffset = yoffset - 20
    xoffset = graphics.card_margin_x

    if has_hidden_card then
        love.graphics.print('total: ?', xoffset, yoffset)
    else
        love.graphics.print('total: '..hand_value(hand), xoffset, yoffset)
    end

    love.graphics.setColor(1,1,1)
end

function Game:print_overlay()
    local graphics = self.settings.graphical

    love.graphics.setColor(0.2,0.2,0.2)

    love.graphics.rectangle("fill", 15, 30, 110, 200)

    love.graphics.setColor(0.4,0.4,0.4)

    love.graphics.rectangle("fill", 5, 15, 110, 200)

    love.graphics.setColor(1,1,1)
end

function Game:print_deck()
    local graphics = self.settings.graphical

    print_text_shadow(#self.state.deck..'/52',
        graphics.deck_margin_x + (graphics.card_spacing_x * 0.35),
        graphics.deck_margin_y + graphics.card_spacing_y + 5)

    local margin_x = graphics.deck_margin_x + (#self.state.deck/4)
    local margin_y = graphics.deck_margin_y + (#self.state.deck/10)

    for i = 1, #self.state.deck do
        love.graphics.draw(self.resources.images.deck_back,
            (-i/5) + margin_x,
            (-i/10) + margin_y)
    end
end

function Game:player_hit()
    Game:draw_for('player')
end

function Game:dealer_autohit()
    local dealer_min = self.settings.gameplay.dealer_score_min

    while Game:hand_value('dealer') < dealer_min do
        Game:draw_for('dealer')
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
    local check = check_win(
        self.state.round.hands.player,
        self.state.round.hands.dealer,
        self.settings.gameplay)

    self.state.round.flags.winner = check.win
    self.state.round.flags.winmsg = check.msg
end

function Game:round_end()
    self.state.round.flags.player_can_hit = false

    self:request_dealer_autohit()
    self:request_reveal_cards()
    self:request_check_win()
end

function Game:process()
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
        local graphics = self.settings.graphical

        love.graphics.setColor(0,0,0)

        love.graphics.print(self.state.round.flags.winmsg,
            graphics.deck_margin_x + (graphics.card_spacing_x * 0.35),
            graphics.card_margin_y + graphics.card_spacing_y + 150)

        love.graphics.setColor(1,1,1)
    end
end

-- Love functions

function love.load()
    Game:load_images()
    Game:reset()

    love.graphics.setBackgroundColor(1, 1, 1)
end

function love.draw()
    Game:print_overlay()
    Game:print_cards('player')
    Game:print_cards('dealer')
    Game:print_deck()

    Game:print_winner()
end

function love.update()

    Game:process()

    -- no cards?
    if #Game.state.deck < 1 then
        Game:request_round_end()
    end
end

function love.keypressed(key)
    if key == 'h' then
        Game:request_player_hit()
    elseif key == 's' then
        Game:request_round_end()
    elseif key == 'r' then
        Game:request_game_reset()
    end
end


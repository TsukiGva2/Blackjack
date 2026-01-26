
Queue = require('queue')

Ace = 1
J   = 11
Q   = 12
K   = 13

function build_deck()
    local deck = {}

	for i, suit in ipairs({'hearts', 'spades', 'diamonds', 'clubs'}) do
		for rank = 1, 13 do
            local image = rank + (13 * (i - 1))

			table.insert(deck, {
                suit   = suit,
                rank   = rank,
                image  = image,
                hidden = false,
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
        if card.rank == Ace then
            has_ace = true
        end

        total = total + card_value
    end

    if has_ace and total <= 11 then
        total = total + 10
    end

    return total
end

function print_card(card, player, index, g)
    local xoffset = 0
    local yoffset = 0

    if player == 'player' then
        yoffset = g.card_spacing_y + g.card_margin_y + g.card_margin_players_y
    else
        yoffset = g.card_margin_y
    end

    local xoffset = g.card_margin_x + (index - 1) * g.card_spacing_x

    if card.hidden then
        love.graphics.draw(images.deck_back, xoffset, yoffset)
        return
    end

    love.graphics.draw(images[card.image], xoffset, yoffset)
end

function draw_card(deck, hand)
    table.insert(hand,
        table.remove(deck, love.math.random(#deck)))
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
        },
    },

    -- General state of the game, the deck, and the round-specific state
    -- e.g. hands.
    state = {
        -- We draw from the same deck every round
        -- and only rebuild once we run out of cards
        deck = {},

        -- state for a specific round of the game
        round = {
            -- Stays nil until game has a defined winner
            winner = nil,

            -- Player and dealer's hands
            hands = {
                player = {},
                dealer = {},
            },

            flags = {

                -- Number of cards hidden per player.
                -- TODO: hide INDEX instead of number of cards
                cards_hidden = {
                    dealer = 0,
                    player = 0,
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
            score_thresh = 21,
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
            deck_margin_x = 10,

            card_margin_x = 130,
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
    for card = 1, game.const.CARDS do
        local path = string.format('images/%02d.png', card)
        images.cards[card] = love.graphics.newImage(path)
    end
end

function

function Game:enqueue(e)
    Queue.push(self.state.events, e)
end

function Game:request_dealer_automatic_hit()
    self:enqueue(DEALER_AUTOHIT)
end

function Game:request_player_hit()
    self:enqueue(PLAYER_HIT)
end

function Game:request_score_update()
    self:enqueue(SCORE_UPDATE)
end

function Game:build_deck()
    self.state.deck = build_deck()
end

function Game:draw_card(who)
    if who == 'player' then
        draw_card(self.state.deck, self.state.round.hands.player)
    else
        draw_card(self.state.deck, self.state.round.hands.dealer)
    end

    self:request_score_update()
end

function Game:reset()
    self.state.round.winner = nil
    self.state.events = Queue.new()

    -- TODO: make hand size configurable
    if #deck < 4 then
        self:build_deck()
    end

	self.state.round.hands = {
        player = {},
        dealer = {},
    }

    -- Maybe apply deck special effects here?
    self.state.round.flags.cards_hidden = {
        dealer = 1,
        player = 0,
    }

    -- Drawing cards

    local player_hidden = self.state.round.flags.cards_hidden.player
    local dealer_hidden = self.state.round.flags.cards_hidden.dealer
    
    self:draw_card('player')
    self:draw_card('player')

    self:draw_card('dealer')
    self:draw_card('dealer')

    for i = 1, player_hidden do
        self.state.round.hands.player[i].hidden = true
    end

    for i = 1, dealer_hidden do
        self.state.round.hands.dealer[i].hidden = true
    end
end

function love.load()
    Game:load_images()
    Game:reset()

    love.graphics.setBackgroundColor(1, 1, 1)
end

function print_cards(hand, player)
    for i, card in ipairs(hand) do
        print_card(card, player, i)
    end

    love.graphics.setColor(0,0,0)

    -- hand totals

    if player == 'player' then
        yoffset = card_spacing_y + card_margin_y + card_margin_players_y - 20
    else
        yoffset = card_margin_y - 20
    end

    xoffset = card_margin_x

    if can_print(player, 1) then
        love.graphics.print('total: '..hand_value(hand), xoffset, yoffset)
    else
        love.graphics.print('total: ?', xoffset, yoffset)
    end

    love.graphics.setColor(1,1,1)
end

function print_deck()
    love.graphics.setColor(0,0,0)

    love.graphics.print(#deck..'/52',
        deck_margin_x + (card_spacing_x * 0.35),
        card_margin_y + card_spacing_y + 5)

    love.graphics.setColor(1,1,1)

    for i = 1, #deck do
        love.graphics.draw(images.deck_back, i/4 + deck_margin_x, i/10 + card_margin_y)
    end
end

-- end logging output shit

function love.draw()
    --addline('Player hand: ')
    print_cards(player_hand, "player")

    --addline('Dealer hand: ')
    print_cards(dealer_hand, "dealer")

    print_deck()

    -- when winner is decided
    if winner then
        --addline('')
        --addline(winmsg)
    end
end

function bust(hand_score)
    return hand_score > score_thresh
end

function check_win(player_score, dealer_score)
    if bust(player_score) then
        return {
            win = 'dealer',
            msg = 'Dealer wins (player bust)'
        }
    end

    if bust(dealer_score) then
        return {
            win = 'player',
            msg = 'Player wins (dealer bust)'
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

function round_end()
    waiting_dealer_hit = true
end

function love.update()
    if waiting_score_update then
        player_score = hand_value(player_hand)

        -- Player wins/loses
        if bust(player_score) or player_score == score_thresh then
            round_end()
        end

        waiting_score_update = false
    end

    if waiting_dealer_hit then
        -- Dealer hit
        while hand_value(dealer_hand) < 17 do
            draw_card(deck, dealer_hand)
        end

        waiting_dealer_hit = false
        round_over = true
    end

    -- no cards?
    if #deck < 1 then
        round_over = true
    end

    if round_over and winner == nil then
        local player_score = hand_value(player_hand)
        local dealer_score = hand_value(dealer_hand)
        local check        = check_win(player_score, dealer_score)

        winner = check.win
        winmsg = check.msg
    end
end

function love.keypressed(key)
    if key == 'h' and not round_over then
        draw_card(deck, player_hand)
    elseif key == 's' then
        round_end()
    elseif key == 'r' then
        reset()
    end
end


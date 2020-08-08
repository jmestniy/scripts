script_name('Snake mini-game')
script_author('arsuhinars')

-- Загружаем необходимые модули
local inicfg = require 'inicfg'
local vkeys = require 'vkeys'
local moonloader = require 'moonloader'

-- Файл настроек скрипта
local cfg = inicfg.load({
    params = {
        fontColor = 0xFFFFFFFF,
        snakeColor = 0xFF1E90FF,
        deadSnakeColor = 0xFF0000CD,
        bgColor = 0xC8000000,
        ceilColor = 0xFF696969,
        appleColor = 0xFFFF0000,
        wallColor = 0xFFC0C0C0,
        speed = 0.5,
        fieldSize = 12,
        hasWalls = false
    },
    data = {
        record = 0
    }
}, 'snake.ini')

-- Получаем разрешение экрана и находим размер и позицию окна игры
local resX, resY = getScreenResolution()
local winSize = resY / 2
local winX = (resX - winSize) / 2
local winY = (resY - winSize) / 2
local fieldOffset = winSize * 0.15                      -- Отступ для поля
local ceilSize = winSize * 0.7 / cfg.params.fieldSize   -- Размер одной клетки
local ceilOffset = ceilSize * 0.1                       -- Отступ для клетки
local realCeilSize = ceilSize * 0.8                     -- Реальный размер клетки
local padding = resX * 0.01                             -- Отступ для текста

-- Состояние игры
local isActivated = false
local isStarted = false
local score = 0             -- Текущий счет
local lastUpdate = 0.0      -- Время прошлого кадра
local timeDelta = 0.0       -- Разница между предыдущим кадром и текущим(секунды)

-- Шрифт игры
local fontSize = resY * 0.02
local font = renderCreateFont('Arial', fontSize, moonloader.font_flag.BOLD)

local snake = {}        -- Массив всех клеток змеи
local apple = {}        -- Координата яблока
local moveSide = 0      -- Сторона, в которую движется змейка(0 - вверх, 1 - вправо, 2 - вниз, 3 - влево)
local nextMoveSide = 0  -- Сторона движения змейки при следующем обновлении
local timer = 0.0       -- Таймер игры

-- Главная функция
function main()
    inicfg.save(cfg, 'snake.ini')
sampRegisterChatCommand("snake", function() isActivated = not isActivated end)
    -- Основной цикл игры
    while true do
        wait(0)     -- Задержка в 1 кадр
        
        update()    -- Обновляем игру
        render()    -- Отрисовываем игру
    end
end

-- Функция обновления игры
function update()
    -- Если была нажата клавиша F5
    if wasKeyPressed(vkeys.VK_F5) then
        isActivated = not isActivated   -- Переключаем состояние скрипта
        lockPlayerControl(isActivated)  -- Замораживаем игрока, если скрипт активирован
    end

    timeDelta = gameClock() - lastUpdate
    lastUpdate = gameClock()

    -- Обновляем, только если включен скрипт
    if not isActivated then 
        return end

    -- Если игра не начата и нажата клавиша E
    if not isStarted and wasKeyPressed(vkeys.VK_E) then
        startGame()
    end

    -- Продолжаем только если игра запущена
    if not isStarted then
        return end

    -- Проверяем нажатие клавиш
    if wasKeyPressed(vkeys.VK_W) and moveSide ~= 2 then
        nextMoveSide = 0
    elseif wasKeyPressed(vkeys.VK_D) and moveSide ~= 3 then
        nextMoveSide = 1
    elseif wasKeyPressed(vkeys.VK_S) and moveSide ~= 0 then
        nextMoveSide = 2
    elseif wasKeyPressed(vkeys.VK_A) and moveSide ~= 1 then
        nextMoveSide = 3
    end

    -- Продолжаем только если пришло время обновления
    timer = timer + timeDelta
    if timer < cfg.params.speed then
        return end
    timer = 0

    moveSide = nextMoveSide

    -- Двигаем хвост к голове
    for i = table.maxn(snake), 2, -1 do
        snake[i].x = snake[i - 1].x
        snake[i].y = snake[i - 1].y
    end

    -- Двигаем голову
    headPos = {}
    if moveSide == 0 then       -- Движемся наверх
        headPos.x = snake[1].x
        headPos.y = snake[1].y - 1
    elseif moveSide == 1 then   -- Движемся вправо
        headPos.x = snake[1].x + 1
        headPos.y = snake[1].y
    elseif moveSide == 2 then   -- Движемся вниз
        headPos.x = snake[1].x
        headPos.y = snake[1].y + 1
    elseif moveSide == 3 then   -- Движемся влево
        headPos.x = snake[1].x - 1
        headPos.y = snake[1].y
    end

    -- Проверяем, скушала ли змейка яблоко
    if snake[1].x == apple.x and snake[1].y == apple.y then
        score = score + 1
        spawnApple()
        table.insert(snake, 1, headPos)
    else
        snake[1] = headPos
    end

    if not cfg.params.hasWalls then
        -- Если голова ушла за границу поля по горизонтали, то возвращаяем её на другой стороне.
        if snake[1].x < 0 then
            snake[1].x = cfg.params.fieldSize - 1
        elseif snake[1].x >= cfg.params.fieldSize then
            snake[1].x = 0
        end

        -- ...по вертикали
        if snake[1].y < 0 then
            snake[1].y = cfg.params.fieldSize - 1
        elseif snake[1].y >= cfg.params.fieldSize then
            snake[1].y = 0
        end
    else
        -- Проверка столкновения змейки со стеной
        if snake[1].x == 0 or snake[1].x == cfg.params.fieldSize - 1 or snake[1].y == 0 or snake[1].y == cfg.params.fieldSize - 1 then
            isStarted = false
            return
        end
    end

    -- Проверяем столкновение змейки с собой
    for i = 2, table.maxn(snake) do
        if snake[1].x == snake[i].x and snake[1].y == snake[i].y then
            isStarted = false
            return
        end
    end
end

-- Функция запуска игры
function startGame()
    isStarted = true

    -- Если побили рекорд
    if score > cfg.data.record then
        cfg.data.record = score
        inicfg.save(cfg, 'snake.ini')
    end
    score = 0

    snake = {}
    moveSide = 0
    nextMoveSide = 0
    local center = cfg.params.fieldSize / 2
    for i = 2, 0, -1 do
        table.insert(snake, {
            x = center,
            y = center - i
        })
    end
    
    spawnApple()    -- Спавним яблоко
end

-- Функция спавна яблока
function spawnApple()
    if not cfg.params.hasWalls then
        apple = {
            x = math.random(0, cfg.params.fieldSize - 1),
            y = math.random(0, cfg.params.fieldSize - 1)
        }
    else
        apple = {
            x = math.random(1, cfg.params.fieldSize - 2),
            y = math.random(1, cfg.params.fieldSize - 2)
        }
    end
end

-- Функция отрисовки игры
function render()
    -- Отрисовываем, только если включен скрипт
    if not isActivated then
        return end

    -- Рисуем фон
    renderDrawBox(winX, winY, winSize, winSize, cfg.params.bgColor)

    -- Рисуем поле
    for x = 1, cfg.params.fieldSize do
        for y = 1, cfg.params.fieldSize do
            if cfg.params.hasWalls and (x == 1 or y == 1 or x == cfg.params.fieldSize or y == cfg.params.fieldSize) then
                renderCeil(x - 1, y - 1, cfg.params.wallColor)
            else
                renderCeil(x - 1, y - 1, cfg.params.ceilColor)
            end
        end
    end

    -- Рисуем яблоко
    if apple.x ~= nil and apple.y ~= nil then
        renderCeil(apple.x, apple.y, cfg.params.appleColor)
    end

    -- Рисуем змейку
    for i = 1, table.maxn(snake) do
        renderCeil(snake[i].x, snake[i].y, cfg.params.snakeColor)
    end

    if not isStarted and table.maxn(snake) > 0 then
        renderCeil(snake[1].x, snake[1].y, cfg.params.deadSnakeColor)
    end

    -- Рисуем тексты
    renderFontDrawText(font, 'Score: ' .. tostring(score), winX + padding, winY + padding, cfg.params.fontColor)

    local text = 'Record: ' .. tostring(cfg.data.record)
    local length = renderGetFontDrawTextLength(font, text)
    renderFontDrawText(font, text, winX + winSize - padding - length, winY + padding, cfg.params.fontColor)

    if not isStarted then
        text = 'Press E to start'
        length = renderGetFontDrawTextLength(font, text)
        renderFontDrawText(font, text, winX + (winSize - length) / 2, winY + winSize - fontSize - padding, cfg.params.fontColor)
    end
end

-- Функция отрисовки клетки
function renderCeil(x, y, color)
    renderDrawBox(
        winX + fieldOffset + ceilSize * x + ceilOffset,
        winY + fieldOffset + ceilSize * y + ceilOffset,
        realCeilSize, realCeilSize, color)
end

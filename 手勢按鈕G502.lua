
    -- 動作間隔限制的全域變數
    local lastActionTime = 0  -- 記錄上次執行動作的時間
    local minActionTimeDelta = 200  -- 動作之間的最短間隔（毫秒）

    -- 除錯模式：啟用時不會執行任何動作
    local debug = false

    -- 智慧按鈕／G Smart Button
    local GSmartButton0 = 9  -- Logitech 控制面板中指定給 G Smart Button 的按鈕（數字x代表Gx按鍵）
    local GSmartButton1 = 7  -- Logitech 控制面板中指定給 G Smart Button 的按鈕
    local GShiftButton = 6  -- Logitech 控制面板中指定給 G Shift 的按鈕 
    local smartButtonDelta = 350  -- 判定為長按的時間(ms)
    local smartButtonDistanceMin = 1000  -- 判定為移動手勢的最短距離
    local smartButtonDistanceMax = 60000  -- 移動手勢的最長距離
    
    local GShiftActive = false  -- 記錄 G-Shift 是否正按住
    local GSmartButtonActive0 = false -- 記錄 G Smart Button 是否正按住
    local GSmartButtonActive1 = false
    local GSmartButtonAction = false -- 記錄按下 G Smart Button 後是否按過其他按鍵，或已經執行過動作
    local smartButtonStart = 0
    local smx1, smy1 = 0, 0
    
    -- 連續按下按鍵的時間與間隔設定
    local keyHoldMs = 25  -- 全部按鍵按下後，維持的時間(ms)
    local keyReleaseGapMs = 10  -- 依序放開按鍵時的間隔(ms)



    -- 更新 G-Shift 按鈕狀態，用於判斷是否處於 G-Shift 模式
    local function updateGShiftState(event)
        if event == "MOUSE_BUTTON_PRESSED" then
            GShiftActive = true
        elseif event == "MOUSE_BUTTON_RELEASED" then
            GShiftActive = false
        end

        if debug and (event == "MOUSE_BUTTON_PRESSED" or event == "MOUSE_BUTTON_RELEASED") then
            OutputLogMessage("G-Shift active: "..tostring(GShiftActive).."\n")
        end
    end

    -- 依序按下按鍵，短暫維持後再依相反順序逐一放開。
    -- intervalMs 是按下按鍵之間的延遲（毫秒）。
    local function pressKeySequence(intervalMs, ...)
        if type(intervalMs) ~= "number" or intervalMs < 0 then
            error("pressKeySequence requires a non-negative interval")
        end

        local keyCount = select("#", ...)
        if keyCount == 0 then
            error("pressKeySequence requires at least one key")
        end

        for i = 1, keyCount do
            PressKey(select(i, ...))
            if i < keyCount then
                Sleep(intervalMs)
            end
        end

        Sleep(keyHoldMs)
        for i = keyCount, 1, -1 do
            ReleaseKey(select(i, ...))
            if i > 1 then
                Sleep(keyReleaseGapMs)
            end
        end
    end

    local function getDirection(dx, dy, way8)
        -- 根據位移量判斷方向的輔助函式
        local absDx = math.abs(dx)
        local absDy = math.abs(dy)

        if not way8 then
            if absDx > absDy then
                return dx > 0 and "RIGHT" or "LEFT"
            else
                return dy > 0 and "DOWN" or "UP"
            end
        end

        if absDx > absDy * 2 then
            return dx > 0 and "RIGHT" or "LEFT"
        elseif absDy > absDx * 2 then
            return dy > 0 and "DOWN" or "UP"
        else
            -- 對角方向
            if dx > 0 and dy > 0 then return "DOWN_RIGHT"
            elseif dx > 0 and dy < 0 then return "UP_RIGHT"
            elseif dx < 0 and dy > 0 then return "DOWN_LEFT"
            else return "UP_LEFT" end
        end
    end

    -- 依據按住時間、位移距離與方向判斷動作
    local function classifySmartButtonAction(duration, dx, dy, distance, way8)
        -- 判斷方向，不計算角度
        local direction = getDirection(dx, dy, way8)

        if debug then
            OutputLogMessage("Mouse moved by: "..dx..", "..dy..". ")
            OutputLogMessage("Direction: "..direction..", distance: "..distance..".\n")
        end

        if GSmartButtonAction then
            -- 不執行動作：G Smart Button 已經執行過動作
            OutputLogMessage("Cancel action: G Smart Button action already performed \n")
            return nil
        elseif distance > smartButtonDistanceMax then
            -- 不執行動作：移動距離過大
            OutputLogMessage("Cancel action: Moved too far (".. distance .." > ".. smartButtonDistanceMax ..")\n")
            return nil
        
        -- 滑鼠移動距離小於 smartButtonDistanceMin 時，判定為簡單點擊
        elseif distance < smartButtonDistanceMin then
            -- 簡單點擊
            if duration < smartButtonDelta then
                OutputLogMessage("Short click (".. duration /1000 .."s < ".. smartButtonDelta/1000 .."s) \n")
            elseif distance < smartButtonDistanceMin then
                OutputLogMessage("No movement (".. distance .." < ".. smartButtonDistanceMin ..")\n")
            end

            if duration < smartButtonDelta then
                -- 短按
                return "SHORT_CLICK"
            end
            -- 長按
            return "LONG_CLICK"
        end

        return direction
    end

    -- 執行智慧按鈕動作的函式，False 表示沒有執行動作，True 表示已經執行動作
    local function SmartButton0Action(action)
        if not action then
            return false
        end
        OutputLogMessage(action.."\n")

        -- debug 模式下不執行任何動作
        if debug then
            return false
        end

        if action == "SHORT_CLICK" then
            PlayMacro("媒體:播放/暫停")
            return true
        elseif action == "LONG_CLICK" then
            PlayMacro("媒體:停止")
            return true
        elseif action == "LEFT" then
            -- 向左
            pressKeySequence(100, "lgui", "lctrl", "left")
            -- PlayMacro("切換左側桌面")
            return true
        elseif action == "RIGHT" then
            -- 向右
            pressKeySequence(100, "lgui", "lctrl", "right")
            -- PlayMacro("切換右側桌面")
            return true
        elseif action == "UP" then
            -- 向上
            PlayMacro("媒體:上一首")
            -- PressAndReleaseKey("escape")
            -- PressKey("escape")
            -- ReleaseKey("escape")
            return true
        elseif action == "DOWN" then
            -- 向下
            PlayMacro("媒體:下一首")
            -- PressAndReleaseKey("lgui", "d")
            return true
        elseif action == "UP_LEFT" then
            -- 左上
            --PlayMacro("")
            -- actionPerformed = true
        elseif action == "UP_RIGHT" then
            -- 右上
            --PlayMacro("")
            -- actionPerformed = true
        elseif action == "DOWN_LEFT" then
            -- 左下
            --PlayMacro("")
            -- actionPerformed = true
        elseif action == "DOWN_RIGHT" then
            -- 右下
            --PlayMacro("")
            -- actionPerformed = true
        end

        return false
    end

    local function SmartButton1Action(action)
        if not action then
            return false
        end
        OutputLogMessage(action.."\n")

        -- debug 模式下不執行任何動作
        if debug then
            return false
        end

        if action == "SHORT_CLICK" then
            -- 短按
            -- 應用程式清單
            pressKeySequence(100, "lalt", "lctrl", "tab")
            return true
        elseif action == "LONG_CLICK" then
            -- 長按
            -- enter 鍵，用來確認選擇的應用程式
            PressAndReleaseKey("enter")
            return true
            
        elseif action == "LEFT" then
            -- 向左
            -- 循環切換應用程式
            pressKeySequence(100, "lalt", "escape")
            return true
        elseif action == "RIGHT" then
            -- 向右
            -- 反向循環切換應用程式
            pressKeySequence(100, "lalt", "lshift", "escape")
            return true
        elseif action == "UP" then
            -- 向上
            pressKeySequence(100, "lgui", "tab")
            return true
        elseif action == "DOWN" then
            -- 向下
            pressKeySequence(100, "lgui", "d")
            return true
        elseif action == "UP_LEFT" then
            -- 左上
            --PlayMacro("")
            -- actionPerformed = true
        elseif action == "UP_RIGHT" then
            -- 右上
            --PlayMacro("")
            -- actionPerformed = true
        elseif action == "DOWN_LEFT" then
            -- 左下
            --PlayMacro("")
            -- actionPerformed = true
        elseif action == "DOWN_RIGHT" then
            -- 右下
            --PlayMacro("")
            -- actionPerformed = true
        end

        return false
    end

    -- 重置所有智慧按鈕狀態
    local function resetSmartButtonState()
        GSmartButtonActive0 = false
        GSmartButtonActive1 = false
        GSmartButtonAction = false
    end

    -- 檢查距離上次動作是否已經過足夠時間
    local function SmartButtonTimeCheck()
        local currentTime = GetRunningTime()
            local timeSinceLastAction = currentTime - lastActionTime

            if timeSinceLastAction < minActionTimeDelta then
                OutputLogMessage("Action throttled: Last action too recent (".. timeSinceLastAction .."ms < ".. minActionTimeDelta .."ms)\n")
                GSmartButtonActive0 = false
                GSmartButtonAction = false
                return false
            end
        return true
    end

    local function finishSmartButton0()
        if not GSmartButtonActive0 then
            return
        end

        -- 檢查距離上次動作是否已經過足夠時間
        if not SmartButtonTimeCheck() then
            return
        end

        local duration = GetRunningTime() - smartButtonStart
        local smx2, smy2 = GetMousePosition()
        local smxDelta = smx2 - smx1
        local smyDelta = smy2 - smy1
        local distance = math.floor(math.sqrt(smxDelta^2 + smyDelta^2))

        -- 依據按住時間、位移距離與方向判斷動作
        local action = classifySmartButtonAction(duration, smxDelta, smyDelta, distance, false)
        -- 若已執行動作，更新上次動作時間
        if SmartButton0Action(action) then
            lastActionTime = GetRunningTime()
        end

        resetSmartButtonState()
    end

    local function finishSmartButton1()
        if not GSmartButtonActive1 then
            return
        end

        -- 檢查距離上次動作是否已經過足夠時間
        if not SmartButtonTimeCheck() then
            return
        end

        local duration = GetRunningTime() - smartButtonStart
        local smx2, smy2 = GetMousePosition()
        local smxDelta = smx2 - smx1
        local smyDelta = smy2 - smy1
        local distance = math.floor(math.sqrt(smxDelta^2 + smyDelta^2))

        -- 依據按住時間、位移距離與方向判斷動作
        local action = classifySmartButtonAction(duration, smxDelta, smyDelta, distance, false)
        -- 若已執行動作，更新上次動作時間
        if SmartButton1Action(action) then
            lastActionTime = GetRunningTime()
        end

        resetSmartButtonState()
    end
    local function handleOtherEvent(event, arg)
        -- 擷取其他事件
        OutputLogMessage("Event: "..event.." Arg: "..arg.."\n")
        if GSmartButtonActive0 and (event == "MOUSE_BUTTON_PRESSED" or event == "MOUSE_BUTTON_RELEASED") then
            GSmartButtonAction = true
        end
        if GSmartButtonActive1 and (event == "MOUSE_BUTTON_PRESSED" or event == "MOUSE_BUTTON_RELEASED") then
            GSmartButtonAction = true
        end
    end
    -- 第一顆智慧按鈕，主要控制媒體播放、暫停、停止、上一首、下一首，以及切換桌面。
    local function fSmartButton0(event)
        if event == "MOUSE_BUTTON_PRESSED" then
            resetSmartButtonState()
            GSmartButtonActive0 = true
            smartButtonStart = GetRunningTime()
            smx1, smy1 = GetMousePosition()

            -- OutputLogMessage("Mouse at: "..smx1..", "..smy1.."\n");
        elseif event == "MOUSE_BUTTON_RELEASED" then
            finishSmartButton0()
        end
    end

    local function fSmartButton1(event)
        if event == "MOUSE_BUTTON_PRESSED" then
            resetSmartButtonState()
            GSmartButtonActive1 = true
            smartButtonStart = GetRunningTime()
            smx1, smy1 = GetMousePosition()

            -- OutputLogMessage("Mouse at: "..smx1..", "..smy1.."\n");
        elseif event == "MOUSE_BUTTON_RELEASED" then
            finishSmartButton1()
        end
    end

    function OnEvent(event, arg)

        -- 紀錄 G-Shift 按鈕狀態
        if arg == GShiftButton then
            updateGShiftState(event)
            return
        end

        -- 智慧按鈕／G Smart Button
        --
        -- 使用 G Smart Button 按鈕處理手勢、短按與長按動作。
        --
        -- 將 smartButton 設為你指定給 G Smart Button 的按鈕編號；目前預設為 G9。
        -- 將 way8 設為 true 可啟用八方向手勢；設為 false 時只判斷上下左右四個方向。
        -- 建立巨集，並修改程式中 Left/Right/Up/Down/... 對應的 PlayMacro("巨集名稱")。
        -- 也可以直接撰寫 PressKey()/ReleaseKey()/pressKeySequence() 按鍵操作。
        if (arg == GSmartButton0) and (not GShiftActive) then
            -- if event == "MOUSE_BUTTON_PRESSED" then
            --     startSmartButtonGesture()
            -- elseif event == "MOUSE_BUTTON_RELEASED" then 
            --     finishSmartButtonGesture()ㄎ
            -- end
            fSmartButton0(event)
            return
        end
        --  
        if (arg == GSmartButton1) and (not GShiftActive) then
            fSmartButton1(event)
            return
        end


        handleOtherEvent(event, arg)
    end
; snake.asm
.386
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc
include \masm32\include\masm32.inc
include \masm32\include\winmm.inc

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\masm32.lib
includelib \masm32\lib\winmm.lib

WinMain proto :DWORD,:DWORD,:DWORD,:DWORD

.data
    ClassName db "SnakeGameClass",0
    AppName   db "Snake Game",0
    fmtScore  db "Score: %d  Best: %d",0
    strGameOver db "GAME OVER",0
    strModeInfo db "Mode: %s",0
    strModeWrap db "Classic",0
    strModeWall db "Boundaried",0
    strMenuRestart db "Restart",0
    strMenuBack db "Main Menu",0
    
    strMenuTitle db "SNAKE GAME",0
    strMenuOpt1 db "Classic Mode",0
    strMenuOpt2 db "Boundaried Mode",0
    strMenuBest db "Current Records:",0
    strMenuBestClassic db "Classic Best: %d",0
    strMenuBestBoundaried db "Boundaried Best: %d",0
    
    szMciOpenMusic    db "open Music\music.mp3 type mpegvideo alias bg",0
    szMciPlayMusic    db "play bg repeat",0
    szMciOpenFood     db "open Music\food.mp3 type mpegvideo alias food",0
    szMciPlayFood     db "play food from 0",0
    szMciOpenGameOver db "open Music\gameover.mp3 type mpegvideo alias death",0
    szMciPlayGameOver db "play death from 0",0
    szMciCloseAll     db "close all",0
    szMciVolBg        db "setaudio bg volume to 100",0
    szMciVolFood      db "setaudio food volume to 1000",0
    szMciVolDeath     db "setaudio death volume to 1000",0
    szMciStopBg       db "stop bg",0
    
    GRID_WIDTH  equ 30
    GRID_HEIGHT equ 20
    CELL_SIZE   equ 20
    OFFSET_X    equ 20
    OFFSET_Y    equ 50 ; More space at top for score visibility
    
    WINDOW_STYLE equ WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX
    
    FileName  db "scores.dat",0
    FontName  db "Arial Bold",0
    
    ; Colors (COLORREF: 0x00bbggrr)
    COLOR_BG    equ 00000000h
    COLOR_SNAKE_BODY equ 0000CC00h ; Slightly darker green
    COLOR_SNAKE_HEAD equ 0000FF00h ; Pure Green
    COLOR_FOOD  equ 000000FFh ; Red
    COLOR_TEXT  equ 00FFFFFFh ; White
    COLOR_BORDER equ 00808080h ; Grey
    
    SnakeLength DWORD 3
    Direction   DWORD 1 ; 0=Up, 1=Right, 2=Down, 3=Left
    GameOver    DWORD 0
    Score       DWORD 0
    GameMode    DWORD 0 ; 0=Wrap, 1=Wall
    GameState   DWORD 0 ; 0=Menu, 1=Playing, 2=GameOver
    MenuSelected DWORD 0 ; 0=Opt1, 1=Opt2
    HighScoreWrap DWORD 0
    HighScoreWall DWORD 0
    
    CurrentDelay    DWORD 150
    MIN_DELAY       equ 50
    NormalFoodCount DWORD 0
    FoodType        DWORD 0 ; 0=Normal, 1=Yellow
    LastMoveDirection DWORD 1 ; 0=Up, 1=Right, 2=Down, 3=Left
    
    COLOR_SCORE  equ 00FFFFFFh ; White
    COLOR_RED    equ 000000FFh ; Red (Color of food and selection)
    COLOR_YELLOW equ 0000FFFFh ; Yellow (Special)
    COLOR_EYE    equ 00000000h ; Black for eyes
    
    FoodX       DWORD 15
    FoodY       DWORD 10
    
    rand_seed   DWORD 0
    msg         MSG <?>

.data?
    hInstance HINSTANCE ?
    SnakeX DWORD 1000 dup(?)
    SnakeY DWORD 1000 dup(?)
    
    dwRead     DWORD ?
    dwWrite    DWORD ?
    hFile      HANDLE ?
    hFontTitle HFONT ?
    hFontMenu  HFONT ?
    hOldFont   HGDIOBJ ?
    hBrushEye  HBRUSH ?
    headLeft   DWORD ?
    headTop    DWORD ?
    
    buffer db 64 dup(?)

.code
; ---------------------------------------------------------------------------
; High Score Persistence
LoadScores proc
    invoke CreateFile, ADDR FileName, GENERIC_READ, FILE_SHARE_READ, NULL,
           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax != INVALID_HANDLE_VALUE
        mov hFile, eax
        invoke ReadFile, hFile, ADDR HighScoreWrap, 8, ADDR dwRead, NULL
        invoke CloseHandle, hFile
    .ENDIF
    ret
LoadScores endp

SaveScores proc
    invoke CreateFile, ADDR FileName, GENERIC_WRITE, FILE_SHARE_READ, NULL,
           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax != INVALID_HANDLE_VALUE
        mov hFile, eax
        invoke WriteFile, hFile, ADDR HighScoreWrap, 8, ADDR dwWrite, NULL
        invoke CloseHandle, hFile
    .ENDIF
    ret
SaveScores endp

; ---------------------------------------------------------------------------
; Random Number Generator (LCG)
MathRand proc max_val:DWORD
    mov eax, rand_seed
    mov ecx, 214013
    mul ecx
    add eax, 2531011
    mov rand_seed, eax
    shr eax, 16
    xor edx, edx
    mov ecx, max_val
    div ecx
    mov eax, edx
    ret
MathRand endp

; ---------------------------------------------------------------------------
; Spawn Food function
SpawnFood proc
    local attempts:DWORD
    mov attempts, 100
    
    ; Determine food type
    .IF NormalFoodCount >= 5
        mov FoodType, 1 ; Special (Yellow)
    .ELSE
        mov FoodType, 0 ; Normal (Red)
    .ENDIF
    
SpawnLoop:
    invoke MathRand, GRID_WIDTH
    mov FoodX, eax
    invoke MathRand, GRID_HEIGHT
    mov FoodY, eax
    
    ; Check collision with snake
    mov ecx, SnakeLength
    xor esi, esi
CheckBody:
    mov eax, SnakeX[esi*4]
    cmp eax, FoodX
    jne NextSegment
    mov eax, SnakeY[esi*4]
    cmp eax, FoodY
    jne NextSegment
    ; Collided with body, try again
    dec attempts
    cmp attempts, 0
    je DoneSpawn  ; fallback
    jmp SpawnLoop
NextSegment:
    inc esi
    loop CheckBody
    
DoneSpawn:
    ret
SpawnFood endp

; ---------------------------------------------------------------------------
; Init Game function
InitGame proc
    mov SnakeLength, 3
    mov Direction, 1 ; Right
    mov GameOver, 0
    mov Score, 0
    mov CurrentDelay, 150
    mov NormalFoodCount, 0
    mov FoodType, 0
    mov LastMoveDirection, 1
    
    ; Clear snake arrays to avoid garbage residuals
    xor eax, eax
    mov ecx, 1000
ClearLoop:
    dec ecx
    mov SnakeX[ecx*4], eax
    mov SnakeY[ecx*4], eax
    test ecx, ecx
    jnz ClearLoop

    mov SnakeX[0], 5
    mov SnakeY[0], 10
    mov SnakeX[4], 4
    mov SnakeY[4], 10
    mov SnakeX[8], 3
    mov SnakeY[8], 10
    
    invoke GetTickCount
    mov rand_seed, eax
    
    invoke SpawnFood
    
    ; Audio: Init MCI for MP3
    invoke mciSendString, ADDR szMciCloseAll, NULL, 0, NULL
    invoke mciSendString, ADDR szMciOpenMusic, NULL, 0, NULL
    invoke mciSendString, ADDR szMciPlayMusic, NULL, 0, NULL
    invoke mciSendString, ADDR szMciOpenFood, NULL, 0, NULL
    invoke mciSendString, ADDR szMciOpenGameOver, NULL, 0, NULL
    
    ; Audio: Set Volume Levels
    invoke mciSendString, ADDR szMciVolBg, NULL, 0, NULL
    invoke mciSendString, ADDR szMciVolFood, NULL, 0, NULL
    invoke mciSendString, ADDR szMciVolDeath, NULL, 0, NULL
    ret
InitGame endp

; ---------------------------------------------------------------------------
; WinMain
start:
    invoke GetModuleHandle, NULL
    mov    hInstance, eax

    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL hwnd:HWND
    LOCAL rect:RECT

    mov   wc.cbSize, SIZEOF WNDCLASSEX
    mov   wc.style, CS_HREDRAW or CS_VREDRAW
    mov   wc.lpfnWndProc, OFFSET WndProc
    mov   wc.cbClsExtra, NULL
    mov   wc.cbWndExtra, NULL
    push  hInstance
    pop   wc.hInstance
    mov   wc.hbrBackground, COLOR_WINDOW+1
    mov   wc.lpszMenuName, NULL
    mov   wc.lpszClassName, OFFSET ClassName
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov   wc.hIcon, eax
    mov   wc.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov   wc.hCursor, eax
    invoke RegisterClassEx, ADDR wc

    ; Calculate exact window size for client area
    mov rect.left, 0
    mov rect.top, 0
    mov eax, GRID_WIDTH
    imul eax, CELL_SIZE
    add eax, OFFSET_X * 2
    mov rect.right, eax
    mov eax, GRID_HEIGHT
    imul eax, CELL_SIZE
    add eax, OFFSET_Y + OFFSET_X ; Top offset + Bottom offset
    mov rect.bottom, eax
    
    invoke AdjustWindowRect, ADDR rect, WINDOW_STYLE, FALSE
    
    mov ecx, rect.right
    sub ecx, rect.left ; width
    
    mov edx, rect.bottom
    sub edx, rect.top ; height

    invoke CreateWindowEx, NULL, ADDR ClassName, ADDR AppName,
           WINDOW_STYLE,
           CW_USEDEFAULT, CW_USEDEFAULT, ecx, edx, NULL, NULL, hInst, NULL
    mov   hwnd, eax

    invoke ShowWindow, hwnd, SW_SHOWNORMAL
    invoke UpdateWindow, hwnd

    .WHILE TRUE
        invoke GetMessage, ADDR msg, NULL, 0, 0
        .BREAK .IF (!eax)
        invoke TranslateMessage, ADDR msg
        invoke DispatchMessage, ADDR msg
    .ENDW

    mov     eax, msg.wParam
    ret
WinMain endp

; ---------------------------------------------------------------------------
; WndProc
WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL ps:PAINTSTRUCT
    LOCAL hdc:HDC
    LOCAL drawRect:RECT
    LOCAL hPen:HPEN
    LOCAL hOldPen:HGDIOBJ
    LOCAL hOldBrush:HGDIOBJ
    LOCAL hBrushHead:HBRUSH
    LOCAL hBrushBody:HBRUSH
    LOCAL hBrushBg:HBRUSH
    LOCAL hBrushFood:HBRUSH
    LOCAL eye1:RECT
    LOCAL eye2:RECT

    .IF uMsg == WM_CREATE
        invoke LoadScores
        invoke InitGame
        
        invoke CreateFont, 72, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
               ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
               DEFAULT_QUALITY, DEFAULT_PITCH or FF_SWISS, ADDR FontName
        mov hFontTitle, eax
        
        invoke CreateFont, 36, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
               ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
               DEFAULT_QUALITY, DEFAULT_PITCH or FF_SWISS, ADDR FontName
        mov hFontMenu, eax
        
        invoke SetTimer, hWnd, 1, 100, NULL ; 100 ms timer

    .ELSEIF uMsg == WM_KEYDOWN
        mov eax, wParam
        .IF GameState == 0 ; Menu State
            .IF eax == VK_UP || eax == VK_LEFT
                mov MenuSelected, 0
                invoke InvalidateRect, hWnd, NULL, FALSE
            .ELSEIF eax == VK_DOWN || eax == VK_RIGHT
                mov MenuSelected, 1
                invoke InvalidateRect, hWnd, NULL, FALSE
            .ELSEIF eax == VK_RETURN
                mov eax, MenuSelected
                mov GameMode, eax
                mov GameState, 1
                invoke InitGame
                invoke InvalidateRect, hWnd, NULL, FALSE
            .ENDIF
        .ELSEIF GameState == 1 ; Playing State
            .IF eax == VK_UP && LastMoveDirection != 2
                mov Direction, 0
            .ELSEIF eax == VK_RIGHT && LastMoveDirection != 3
                mov Direction, 1
            .ELSEIF eax == VK_DOWN && LastMoveDirection != 0
                mov Direction, 2
            .ELSEIF eax == VK_LEFT && LastMoveDirection != 1
                mov Direction, 3
            .ENDIF
        .ELSE ; Game Over State
            .IF eax == VK_UP || eax == VK_LEFT
                dec MenuSelected
                .IF sdword ptr MenuSelected < 0
                    mov MenuSelected, 1
                .ENDIF
                invoke InvalidateRect, hWnd, NULL, FALSE
            .ELSEIF eax == VK_DOWN || eax == VK_RIGHT
                inc MenuSelected
                .IF MenuSelected > 1
                    mov MenuSelected, 0
                .ENDIF
                invoke InvalidateRect, hWnd, NULL, FALSE
            .ELSEIF eax == VK_RETURN
                .IF MenuSelected == 0
                    ; Restart Current Mode
                    mov GameState, 1
                    invoke InitGame
                .ELSE
                    ; Back to Main Menu
                    mov GameState, 0
                    mov MenuSelected, 0
                .ENDIF
                invoke InvalidateRect, hWnd, NULL, FALSE
            .ENDIF
        .ENDIF

    .ELSEIF uMsg == WM_TIMER
        .IF GameState == 1
            ; Update physical orientation for input buffering
            mov eax, Direction
            mov LastMoveDirection, eax
            
            ; Move body backwards
            mov ecx, SnakeLength
            dec ecx
            .WHILE ecx > 0
                mov eax, SnakeX[ecx*4 - 4]
                mov SnakeX[ecx*4], eax
                mov eax, SnakeY[ecx*4 - 4]
                mov SnakeY[ecx*4], eax
                dec ecx
            .ENDW

            ; Move Head
            mov eax, SnakeX[0]
            mov edx, SnakeY[0]
            .IF Direction == 0
                dec edx
            .ELSEIF Direction == 1
                inc eax
            .ELSEIF Direction == 2
                inc edx
            .ELSEIF Direction == 3
                dec eax
            .ENDIF
            mov SnakeX[0], eax
            mov SnakeY[0], edx
            
            ; Wall Logic based on GameMode
            .IF GameMode == 0
                ; Mode 1: Wrap-Around
                .IF sdword ptr eax < 0
                    mov eax, GRID_WIDTH - 1
                .ELSEIF eax >= GRID_WIDTH
                    xor eax, eax
                .ENDIF
                
                .IF sdword ptr edx < 0
                    mov edx, GRID_HEIGHT - 1
                .ELSEIF edx >= GRID_HEIGHT
                    xor edx, edx
                .ENDIF
            .ELSE
                ; Mode 2: Wall Collision
                .IF sdword ptr eax < 0 || eax >= GRID_WIDTH || sdword ptr edx < 0 || edx >= GRID_HEIGHT
                    mov GameOver, 1
                    ; Clamp values for rendering safety if dead
                    .IF sdword ptr eax < 0
                        xor eax, eax
                    .ELSEIF eax >= GRID_WIDTH
                        mov eax, GRID_WIDTH - 1
                    .ENDIF
                    .IF sdword ptr edx < 0
                        xor edx, edx
                    .ELSEIF edx >= GRID_HEIGHT
                        mov edx, GRID_HEIGHT - 1
                    .ENDIF
                .ENDIF
            .ENDIF
            
            mov SnakeX[0], eax
            mov SnakeY[0], edx
            
            .IF GameOver == 1
                mov GameState, 2
                
                ; Audio: Stop Background Music and Play Game Over sound (MCI)
                invoke mciSendString, ADDR szMciStopBg, NULL, 0, NULL
                invoke mciSendString, ADDR szMciPlayGameOver, NULL, 0, NULL
                
                ; Update High Scores on game over
                .IF GameMode == 0
                    mov eax, Score
                    .IF eax > HighScoreWrap
                        mov HighScoreWrap, eax
                    .ENDIF
                .ELSE
                    mov eax, Score
                    .IF eax > HighScoreWall
                        mov HighScoreWall, eax
                    .ENDIF
                .ENDIF
            .ENDIF
            
            ; Self Collision
            mov ecx, SnakeLength
            dec ecx
            .WHILE ecx > 0
                mov eax, SnakeX[ecx*4]
                .IF eax == SnakeX[0]
                    mov edx, SnakeY[ecx*4]
                    .IF edx == SnakeY[0]
                        mov GameOver, 1
                    .ENDIF
                .ENDIF
                dec ecx
            .ENDW

            ; Food Collision
            mov eax, SnakeX[0]
            mov edx, SnakeY[0]
            .IF eax == FoodX && edx == FoodY
                .IF FoodType == 1 ; Special (Yellow)
                    add Score, 5
                    mov NormalFoodCount, 0 ; Reset cycle after bonus
                    ; Double speed increase for special
                    .IF CurrentDelay > MIN_DELAY
                        sub CurrentDelay, 4
                        invoke KillTimer, hWnd, 1
                        invoke SetTimer, hWnd, 1, CurrentDelay, NULL
                    .ENDIF
                .ELSE
                    inc Score
                    inc NormalFoodCount
                    ; Normal speed increase
                    .IF CurrentDelay > MIN_DELAY
                        sub CurrentDelay, 2
                        invoke KillTimer, hWnd, 1
                        invoke SetTimer, hWnd, 1, CurrentDelay, NULL
                    .ENDIF
                .ENDIF
                
                ; Play Food Sound (MCI)
                invoke mciSendString, ADDR szMciPlayFood, NULL, 0, NULL
                
                ; Copy last segment position to the new segment to prevent "random square" at (0,0)
                mov esi, SnakeLength
                dec esi
                mov eax, SnakeX[esi*4]
                mov edx, SnakeY[esi*4]
                inc SnakeLength
                mov edi, SnakeLength
                dec edi
                mov SnakeX[edi*4], eax
                mov SnakeY[edi*4], edx
                
                invoke SpawnFood
            .ENDIF

            invoke InvalidateRect, hWnd, NULL, FALSE
        .ENDIF

    .ELSEIF uMsg == WM_PAINT
        invoke BeginPaint, hWnd, ADDR ps
        mov hdc, eax

        ; Draw Background (Always)
        invoke CreateSolidBrush, COLOR_BG
        mov hBrushBg, eax
        invoke GetClientRect, hWnd, ADDR drawRect
        invoke FillRect, hdc, ADDR drawRect, hBrushBg
        invoke DeleteObject, hBrushBg

        .IF GameState == 0 ; Menu State
            invoke SetBkMode, hdc, TRANSPARENT
            
            invoke GetClientRect, hWnd, ADDR drawRect
            
            ; Title (Larger Font)
            invoke SelectObject, hdc, hFontTitle
            mov hOldFont, eax
            invoke SetTextColor, hdc, COLOR_SCORE ; White
            mov drawRect.top, 60
            invoke DrawText, hdc, ADDR strMenuTitle, -1, ADDR drawRect, DT_CENTER or DT_TOP
            
            ; Restore font for other text
            invoke SelectObject, hdc, hOldFont
            
            ; Options (Medium Font)
            invoke SelectObject, hdc, hFontMenu
            mov hOldFont, eax
            
            add drawRect.top, 100
            .IF MenuSelected == 0
                invoke SetTextColor, hdc, COLOR_RED ; Selected is Red
            .ELSE
                invoke SetTextColor, hdc, COLOR_SCORE ; White
            .ENDIF
            invoke DrawText, hdc, ADDR strModeWrap, -1, ADDR drawRect, DT_CENTER or DT_TOP
            
            add drawRect.top, 40
            .IF MenuSelected == 1
                invoke SetTextColor, hdc, COLOR_RED ; Selected is Red
            .ELSE
                invoke SetTextColor, hdc, COLOR_SCORE ; White
            .ENDIF
            invoke DrawText, hdc, ADDR strModeWall, -1, ADDR drawRect, DT_CENTER or DT_TOP
            
            invoke SelectObject, hdc, hOldFont
            
            ; Records (Normal Font)
            add drawRect.top, 80
            invoke SetTextColor, hdc, COLOR_SCORE ; White
            invoke DrawText, hdc, ADDR strMenuBest, -1, ADDR drawRect, DT_CENTER or DT_TOP
            
            add drawRect.top, 30
            invoke wsprintf, ADDR buffer, ADDR strMenuBestClassic, HighScoreWrap
            invoke DrawText, hdc, ADDR buffer, -1, ADDR drawRect, DT_CENTER or DT_TOP
            
            add drawRect.top, 30
            invoke wsprintf, ADDR buffer, ADDR strMenuBestBoundaried, HighScoreWall
            invoke DrawText, hdc, ADDR buffer, -1, ADDR drawRect, DT_CENTER or DT_TOP

        .ELSEIF GameState == 1 || GameState == 2 ; Playing or Game Over
            ; Draw Boundaries (Wider)
            invoke CreatePen, PS_SOLID, 8, COLOR_BORDER
            mov hPen, eax
            invoke SelectObject, hdc, hPen
            mov hOldPen, eax
            invoke GetStockObject, NULL_BRUSH
            invoke SelectObject, hdc, eax
            mov hOldBrush, eax
            
            ; Rect for border centered around the play area
            mov drawRect.left, OFFSET_X - 4
            mov drawRect.top, OFFSET_Y - 4
            mov eax, GRID_WIDTH
            imul eax, CELL_SIZE
            add eax, OFFSET_X + 4
            mov drawRect.right, eax
            mov eax, GRID_HEIGHT
            imul eax, CELL_SIZE
            add eax, OFFSET_Y + 4
            mov drawRect.bottom, eax
            invoke Rectangle, hdc, drawRect.left, drawRect.top, drawRect.right, drawRect.bottom
            
            invoke SelectObject, hdc, hOldBrush
            invoke SelectObject, hdc, hOldPen
            invoke DeleteObject, hPen

            ; Draw Food (Circular)
            .IF FoodType == 1
                invoke CreateSolidBrush, COLOR_YELLOW
            .ELSE
                invoke CreateSolidBrush, COLOR_FOOD
            .ENDIF
            mov hBrushFood, eax
            invoke SelectObject, hdc, hBrushFood
            mov hOldBrush, eax
            
            mov eax, FoodX
            imul eax, CELL_SIZE
            add eax, OFFSET_X
            mov drawRect.left, eax
            add eax, CELL_SIZE
            mov drawRect.right, eax
            
            mov eax, FoodY
            imul eax, CELL_SIZE
            add eax, OFFSET_Y
            mov drawRect.top, eax
            add eax, CELL_SIZE
            mov drawRect.bottom, eax
            
            invoke Ellipse, hdc, drawRect.left, drawRect.top, drawRect.right, drawRect.bottom
            
            invoke SelectObject, hdc, hOldBrush
            invoke DeleteObject, hBrushFood
            
            ; Draw Snake (Head different)
            invoke CreateSolidBrush, COLOR_SNAKE_BODY
            mov hBrushBody, eax
            invoke CreateSolidBrush, COLOR_SNAKE_HEAD
            mov hBrushHead, eax
            
            mov ecx, SnakeLength
            xor esi, esi
        DrawSnakeLoop:
            push ecx
            
            mov eax, SnakeX[esi*4]
            imul eax, CELL_SIZE
            add eax, OFFSET_X
            mov drawRect.left, eax
            add eax, CELL_SIZE
            mov drawRect.right, eax
            
            mov eax, SnakeY[esi*4]
            imul eax, CELL_SIZE
            add eax, OFFSET_Y
            mov drawRect.top, eax
            add eax, CELL_SIZE
            mov drawRect.bottom, eax

            .IF esi == 0
                invoke FillRect, hdc, ADDR drawRect, hBrushHead
                
                ; Save head coordinates for eyes and tongue
                mov eax, drawRect.left
                mov headLeft, eax
                mov eax, drawRect.top
                mov headTop, eax
                
                ; Draw 2 Eyes (Black, 5x5)
                invoke CreateSolidBrush, COLOR_EYE
                mov hBrushEye, eax
                
                mov ebx, headLeft
                mov edx, headTop
                
                .IF Direction == 0 ; Up
                    ; Eye 1 (Top-Left)
                    lea eax, [ebx+3]
                    mov eye1.left, eax
                    lea eax, [edx+3]
                    mov eye1.top, eax
                    lea eax, [ebx+8]
                    mov eye1.right, eax
                    lea eax, [edx+8]
                    mov eye1.bottom, eax
                    ; Eye 2 (Top-Right)
                    lea eax, [ebx+12]
                    mov eye2.left, eax
                    lea eax, [edx+3]
                    mov eye2.top, eax
                    lea eax, [ebx+17]
                    mov eye2.right, eax
                    lea eax, [edx+8]
                    mov eye2.bottom, eax
                .ELSEIF Direction == 1 ; Right
                    ; Eye 1 (Top-Right)
                    lea eax, [ebx+12]
                    mov eye1.left, eax
                    lea eax, [edx+3]
                    mov eye1.top, eax
                    lea eax, [ebx+17]
                    mov eye1.right, eax
                    lea eax, [edx+8]
                    mov eye1.bottom, eax
                    ; Eye 2 (Bottom-Right)
                    lea eax, [ebx+12]
                    mov eye2.left, eax
                    lea eax, [edx+12]
                    mov eye2.top, eax
                    lea eax, [ebx+17]
                    mov eye2.right, eax
                    lea eax, [edx+17]
                    mov eye2.bottom, eax
                .ELSEIF Direction == 2 ; Down
                    ; Eye 1 (Bottom-Left)
                    lea eax, [ebx+3]
                    mov eye1.left, eax
                    lea eax, [edx+12]
                    mov eye1.top, eax
                    lea eax, [ebx+8]
                    mov eye1.right, eax
                    lea eax, [edx+17]
                    mov eye1.bottom, eax
                    ; Eye 2 (Bottom-Right)
                    lea eax, [ebx+12]
                    mov eye2.left, eax
                    lea eax, [edx+12]
                    mov eye2.top, eax
                    lea eax, [ebx+17]
                    mov eye2.right, eax
                    lea eax, [edx+17]
                    mov eye2.bottom, eax
                .ELSEIF Direction == 3 ; Left
                    ; Eye 1 (Top-Left)
                    lea eax, [ebx+3]
                    mov eye1.left, eax
                    lea eax, [edx+3]
                    mov eye1.top, eax
                    lea eax, [ebx+8]
                    mov eye1.right, eax
                    lea eax, [edx+8]
                    mov eye1.bottom, eax
                    ; Eye 2 (Bottom-Left)
                    lea eax, [ebx+3]
                    mov eye2.left, eax
                    lea eax, [edx+12]
                    mov eye2.top, eax
                    lea eax, [ebx+8]
                    mov eye2.right, eax
                    lea eax, [edx+17]
                    mov eye2.bottom, eax
                .ENDIF
                
                invoke FillRect, hdc, ADDR eye1, hBrushEye
                invoke FillRect, hdc, ADDR eye2, hBrushEye
                invoke DeleteObject, hBrushEye
                
                ; Restore drawRect for loop consistency
                mov eax, headLeft
                mov drawRect.left, eax
                add eax, CELL_SIZE
                mov drawRect.right, eax
                mov eax, headTop
                mov drawRect.top, eax
                add eax, CELL_SIZE
                mov drawRect.bottom, eax
            .ELSE
                invoke FillRect, hdc, ADDR drawRect, hBrushBody
            .ENDIF
            
            inc esi
            pop ecx
            dec ecx
            test ecx, ecx
            jnz DrawSnakeLoop
            
            invoke DeleteObject, hBrushBody
            invoke DeleteObject, hBrushHead
            
            ; Draw Text
            invoke SetBkMode, hdc, TRANSPARENT
            invoke SetTextColor, hdc, COLOR_SCORE ; Color White for score
            
            ; Select high score value for current mode
            mov eax, HighScoreWrap
            .IF GameMode == 1
                mov eax, HighScoreWall
            .ENDIF
            
            invoke wsprintf, ADDR buffer, ADDR fmtScore, Score, eax
            
            invoke GetClientRect, hWnd, ADDR drawRect
            mov drawRect.left, OFFSET_X
            mov drawRect.top, 15 ; In the middle of the 50px header
            invoke DrawText, hdc, ADDR buffer, -1, ADDR drawRect, DT_LEFT or DT_TOP
            
            ; Draw Mode name at the bottom or top center
            push OFFSET strModeWrap
            .IF GameMode == 1
                pop eax
                push OFFSET strModeWall
            .ENDIF
            pop edx
            invoke wsprintf, ADDR buffer, ADDR strModeInfo, edx
            invoke GetClientRect, hWnd, ADDR drawRect
            mov drawRect.top, 15
            invoke DrawText, hdc, ADDR buffer, -1, ADDR drawRect, DT_CENTER or DT_TOP

            .IF GameState == 2 ; Game Over State
                invoke GetClientRect, hWnd, ADDR drawRect
                
                ; Game Over Title
                invoke SelectObject, hdc, hFontTitle
                mov hOldFont, eax
                invoke SetTextColor, hdc, COLOR_RED
                mov drawRect.top, 100
                invoke DrawText, hdc, ADDR strGameOver, -1, ADDR drawRect, DT_CENTER or DT_TOP
                
                ; Interactive Selection at Game Over (Medium Font)
                invoke SelectObject, hdc, hFontMenu
                add drawRect.top, 100
                .IF MenuSelected == 0
                    invoke SetTextColor, hdc, COLOR_RED
                .ELSE
                    invoke SetTextColor, hdc, COLOR_SCORE
                .ENDIF
                invoke DrawText, hdc, ADDR strMenuRestart, -1, ADDR drawRect, DT_CENTER or DT_TOP
                
                add drawRect.top, 50
                .IF MenuSelected == 1
                    invoke SetTextColor, hdc, COLOR_RED
                .ELSE
                    invoke SetTextColor, hdc, COLOR_SCORE
                .ENDIF
                invoke DrawText, hdc, ADDR strMenuBack, -1, ADDR drawRect, DT_CENTER or DT_TOP
                
                invoke SelectObject, hdc, hOldFont
            .ENDIF
        .ENDIF

        invoke EndPaint, hWnd, ADDR ps

    .ELSEIF uMsg == WM_DESTROY
        invoke SaveScores
        invoke DeleteObject, hFontTitle
        invoke DeleteObject, hFontMenu
        invoke mciSendString, ADDR szMciCloseAll, NULL, 0, NULL
        invoke KillTimer, hWnd, 1
        invoke PostQuitMessage, NULL

    .ELSE
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .ENDIF

    xor eax, eax
    ret
WndProc endp

end start

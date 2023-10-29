;------------------------------------------------------------------------------
; CD x64 - Compress-Decompress Utility using MS Compression API
; fearless 2023 - github.com/mrfearless
;------------------------------------------------------------------------------
; https://learn.microsoft.com/en-us/windows/win32/cmpapi/-compression-portal
; https://learn.microsoft.com/en-us/windows/win32/cmpapi/using-the-compression-api
; https://learn.microsoft.com/en-us/windows/win32/api/compressapi/nf-compressapi-compress
; https://learn.microsoft.com/en-us/windows/win32/api/compressapi/nf-compressapi-decompress
;------------------------------------------------------------------------------
;
; CD uses the Microsoft Compression API to compress or decompress data using 
; one of the four supported compression algorithms: XPRESS, XPRESS with Huffman
; encoding, MSZIP or LZMS.
;
; The files compressed by CD using those compression algorithms also store a 
; signature DWORD value as the header at the start of the file. This is so that 
; the appropriate compression algorithm can be used for the decompression.
;
; CD also makes use of the compression API to store bitmap resources as LZMS
; compressed data. There are two ways in which CD uses that compressed bitmap
; data: 
;
; 1) In the about box, by uncompressing the bitmap data before creating the 
;    bitmap in memory. The LZMS compressed bitmap data is stored as static hex 
;    bytes in the CD128x128x4.bmp.asm file.
;
; 2) Adding LZMS compressed bitmap files (.lzms) as RC_DATA resources which are 
;    compiled into CD.exe. These resources are loaded into memory, and then 
;    uncompressed before creating the bitmaps in memory.
;
;------------------------------------------------------------------------------
;
; XPRESS
; ------
; Microsoft Xpress Compression Algorithm (MS-XCA), more commonly known as 
; LZXpress, implements the LZ77 algorithm.
;
; XPRESS-HUFFMAN
; --------------
; The Huffman variant of the Microsoft Xpress Compression Algorithm (MS-XCA) 
; uses LZ77-style dictionary compression combined with Huffman coding. 
; Designed for fast compression and decompression with a small dictionary size.
;
; MSZIP
; -----
; MSZIP uses a combination of LZ77 and Huffman coding. It has only minor 
; variations from Phil Katz's 'deflate' method. MSZIP uses only the three basic 
; modes of deflate: stored, fixed Huffman tree, and dynamic Huffman tree.
;
; LZMS
; ----
; LZMS is an LZ77-based algorithm achieving a high compression ratio by relying 
; on a large LZ77 dictionary size and Huffman coding in addition to more 
; concise arithmetic coding.
;
;------------------------------------------------------------------------------
;
; Project->Project Options has a define added to the resource compiler as
; "/d LZMA_RESOURCES" to allow for switching between resource files in CD.rc
; (CDRes.rc.lzma or CDRes.rc.normal):
;
; Compile RC: 4,O,$B\RC.EXE /v /d LZMA_RESOURCES,1
;
; The define in the assembler file should also be uncommented if using LZMA:
;
; LZMA_RESOURCES EQU 1
;
; If not using LZMA resources, then remove the "/d LZMA_RESOURCES" from the 
; resource compiler options and comment out the "LZMA_RESOURCES EQU 1" line
;
;------------------------------------------------------------------------------

.686
.MMX
.XMM
.x64

option casemap : none
option win64 : 11
option frame : auto
option stackbase : rsp

_WIN64 EQU 1
WINVER equ 0501h

LZMA_RESOURCES EQU 1 ; comment out to use normal bitmap resources

;DEBUG64 EQU 1

;IFDEF DEBUG64
;    PRESERVEXMMREGS equ 1
;    includelib \UASM\lib\x64\Debug64.lib
;    DBG64LIB equ 1
;    DEBUGEXE textequ <'\UASM\bin\DbgWin.exe'>
;    include \UASM\include\debug64.inc
;    .DATA
;    RDBG_DbgWin	DB DEBUGEXE,0
;    .CODE
;ENDIF

include CD.inc
include .\Images\CD128x128x4.bmp.asm
include infotext.asm
include AboutDlg.asm
include CDText.asm

.CONST
ERROR_BAD_COMPRESSION_BUFFER     equ 605
ERROR_FUNCTION_FAILED            equ 1627

.CODE

;------------------------------------------------------------------------------
; Startup
;------------------------------------------------------------------------------
WinMainCRTStartup proc FRAME
	Invoke GetModuleHandle, NULL
	mov hInstance, rax
	
    invoke LoadAccelerators, hInstance, ACCTABLE
    mov hAcc, rax
    
	Invoke GetCommandLine
	mov CommandLine, rax	
	Invoke InitCommonControls
	mov icc.dwSize, sizeof INITCOMMONCONTROLSEX
    mov icc.dwICC, ICC_COOL_CLASSES or ICC_STANDARD_CLASSES or ICC_WIN95_CLASSES
    Invoke InitCommonControlsEx, offset icc
	Invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
	Invoke ExitProcess, eax
    ret
WinMainCRTStartup endp

;------------------------------------------------------------------------------
; WinMain
;------------------------------------------------------------------------------
WinMain proc FRAME hInst:HINSTANCE, hPrev:HINSTANCE, CmdLine:LPSTR, iShow:DWORD
	LOCAL msg:MSG
	LOCAL wcex:WNDCLASSEX
	
	mov wcex.cbSize, sizeof WNDCLASSEX
	mov wcex.style, CS_HREDRAW or CS_VREDRAW
	lea rax, WndProc
	mov wcex.lpfnWndProc, rax
	mov wcex.cbClsExtra, 0
	mov wcex.cbWndExtra, DLGWINDOWEXTRA
	mov rax, hInst
	mov wcex.hInstance, rax
	mov wcex.hbrBackground, COLOR_BTNFACE+1
	mov wcex.lpszMenuName, IDM_MENU ;NULL 
	lea rax, ClassName
	mov wcex.lpszClassName, rax
    Invoke LoadIcon, hInstance, ICO_MAIN ; resource icon for main application icon
    mov hIcoMain, rax ; main application icon
	mov wcex.hIcon, rax
	mov wcex.hIconSm, rax
	Invoke LoadCursor, NULL, IDC_ARROW
	mov wcex.hCursor, rax
	Invoke RegisterClassEx, addr wcex
	Invoke CreateDialogParam, hInstance, IDD_DIALOG, 0, Addr WndProc, 0
    mov hWnd, rax
    Invoke ShowWindow, hWnd, SW_SHOWNORMAL
    Invoke UpdateWindow, hWnd
    .WHILE TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .BREAK .if !rax

        Invoke TranslateAccelerator, hWnd, hAcc, addr msg
        .IF rax == 0
            Invoke IsDialogMessage, hWnd, addr msg
            .IF rax == 0
                Invoke TranslateMessage, addr msg
                Invoke DispatchMessage, addr msg
            .ENDIF
        .ENDIF
    .ENDW
	
	mov rax, msg.wParam
	ret	
WinMain endp

;------------------------------------------------------------------------------
; WndProc - Main Window Message Loop
;------------------------------------------------------------------------------
WndProc proc FRAME hWin:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    
    mov eax, uMsg
	.IF eax == WM_INITDIALOG
		; Init Stuff Here
        Invoke InitGUI, hWin
		
    .ELSEIF eax == WM_COMMAND
        mov rax, wParam
        and rax, 0FFFFh
        
        .IF eax == IDM_FILE_EXIT || eax == IDC_BTN_EXIT || eax == ACC_FILE_EXIT || eax == ACC_BTN_EXIT
            Invoke SendMessage, hWin, WM_CLOSE, 0, 0
			
        ;----------------------------------------------------------------------
        ; Compress File
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDM_FILE_OPEN_COMPRESS || eax == IDC_BTN_COMPRESS || eax == ACC_FILE_OPEN_COMPRESS || eax == ACC_BTN_COMPRESS
            Invoke CDBrowseForFile, hWin, TRUE
            .IF eax == TRUE
                Invoke CDOpenFile, Addr CDFileName
                .IF eax == TRUE
                    Invoke CDJustFnameExt, Addr CDFileName, Addr CDFileNameExtOnly
                    Invoke lstrcpy, Addr szStatusBarMsg, Addr szCompressingFile
                    Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                    Invoke lstrcat, Addr szStatusBarMsg, Addr szPleaseWait
                    Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    Invoke CDCompressFile
                    .IF eax == TRUE
                        Invoke lstrcpy, Addr szStatusBarMsg, Addr szCompressedFile
                        Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                        Invoke lstrcat, Addr szStatusBarMsg, Addr szSuccess
                        Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                        
                        ;----------------------------------------------------------
                        ; Output masm hex bytes to .asm file if option is checked
                        ;----------------------------------------------------------
                        .IF bAsmOutput == TRUE
                            Invoke CDJustFnameExt, Addr CDFileName, Addr CDFileNameExtOnlyOutput
                            Invoke CDCloseFile
                            Invoke CDOpenFile, Addr CDCompressedFileName
                            Invoke lstrcat, Addr szStatusBarMsg, Addr szMASMOutputFile
                            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                            Invoke CDOutputAsmFile
                            .IF eax == TRUE
                                Invoke lstrcpy, Addr szStatusBarMsg, Addr szFile
                                Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnlyOutput
                                Invoke lstrcat, Addr szStatusBarMsg, Addr szSuccess
                                Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                            .ELSE
                                Invoke lstrcpy, Addr szStatusBarMsg, Addr szFile
                                Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnlyOutput
                                Invoke lstrcat, Addr szStatusBarMsg, Addr szFailure
                                Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                            .ENDIF
                        .ENDIF
                        
                    .ELSE
                        Invoke lstrcpy, Addr szStatusBarMsg, Addr szCompressedFile
                        Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                        Invoke lstrcat, Addr szStatusBarMsg, Addr szFailure
                        Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    .ENDIF
                    Invoke CDCloseFile
                    
                .ENDIF
            .ENDIF
            
        ;----------------------------------------------------------------------
        ; Decompress File
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDM_FILE_OPEN_DECOMPRESS || eax == IDC_BTN_DECOMPRESS || eax == ACC_FILE_OPEN_DECOMPRESS || eax == ACC_BTN_DECOMPRESS
            Invoke CDBrowseForFile, hWin, FALSE
            .IF eax == TRUE
                Invoke CDOpenFile, Addr CDFileName
                .IF eax == TRUE
                    Invoke CDJustFnameExt, Addr CDFileName, Addr CDFileNameExtOnly
                    Invoke lstrcpy, Addr szStatusBarMsg, Addr szDecompressingFile
                    Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                    Invoke lstrcat, Addr szStatusBarMsg, Addr szPleaseWait
                    Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    Invoke CDDecompressFile
                    .IF eax == TRUE
                        Invoke lstrcpy, Addr szStatusBarMsg, Addr szDecompressedFile
                        Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                        Invoke lstrcat, Addr szStatusBarMsg, Addr szSuccess
                        Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    .ELSE
                        Invoke lstrcpy, Addr szStatusBarMsg, Addr szDecompressedFile
                        Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                        Invoke lstrcat, Addr szStatusBarMsg, Addr szFailure
                        Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
                    .ENDIF
                .ENDIF
            .ENDIF
            
        ;----------------------------------------------------------------------
        ; Radio Button Selections
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_RBN_XPRESS
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDAlgorithm, COMPRESS_ALGORITHM_XPRESS
            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_XPRESS
        
        .ELSEIF eax == IDC_RBN_XPRESS_HUFF
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS_HUFF, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDAlgorithm, COMPRESS_ALGORITHM_XPRESS_HUFF
            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_HUFF
            
        .ELSEIF eax == IDC_RBN_MSZIP
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_MSZIP, BM_SETCHECK, BST_CHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_LZMS, BM_SETCHECK, BST_UNCHECKED, 0
            mov CDAlgorithm, COMPRESS_ALGORITHM_MSZIP
            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_MSZIP
            
        .ELSEIF eax == IDC_RBN_LZMS
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS_HUFF, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_MSZIP, BM_SETCHECK, BST_UNCHECKED, 0
            Invoke SendDlgItemMessage, hWin, IDC_RBN_LZMS, BM_SETCHECK, BST_CHECKED, 0
            mov CDAlgorithm, COMPRESS_ALGORITHM_LZMS
            Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_LZMS
        
        ;----------------------------------------------------------------------
        ; Asm Output Checkbox Selection
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_CHK_ASM
            Invoke SendDlgItemMessage, hWin, IDC_CHK_ASM, BM_GETCHECK, 0, 0
            .IF eax == TRUE
                Invoke SendDlgItemMessage, hWin, IDC_CHK_ASM, BM_SETCHECK, BST_UNCHECKED, 0
                mov bAsmOutput, FALSE
            .ELSE
                Invoke SendDlgItemMessage, hWin, IDC_CHK_ASM, BM_SETCHECK, BST_CHECKED, 0
                mov bAsmOutput, TRUE
            .ENDIF
        
        ;----------------------------------------------------------------------
        ; Asm Segment Checkbox Selection
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_CHK_ASMSEG
            Invoke SendDlgItemMessage, hWin, IDC_CHK_ASMSEG, BM_GETCHECK, 0, 0
            .IF eax == TRUE
                Invoke SendDlgItemMessage, hWin, IDC_CHK_ASMSEG, BM_SETCHECK, BST_UNCHECKED, 0
                mov bAsmDataSeg, FALSE
            .ELSE
                Invoke SendDlgItemMessage, hWin, IDC_CHK_ASMSEG, BM_SETCHECK, BST_CHECKED, 0
                mov bAsmDataSeg, TRUE
            .ENDIF
        
        ;----------------------------------------------------------------------
        ; About Dialog with example of using a lzms compressed bitmap stored
        ; as data bytes in CD128x128x4.bmp.asm, uncompressing it in memory
        ; and creating the bitmap from that uncompressed memory before display
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDM_HELP_ABOUT || eax == IDC_BTN_ABOUT || eax == ACC_HELP_ABOUT
            Invoke DialogBoxParam, hInstance, IDD_AboutDlg, hWin, Addr AboutDlgProc, NULL
        
        ;----------------------------------------------------------------------
        ; Hidden easter egg option! Output file like BIN2DBEX does but to .asm
        ; Doesnt do any compression, just raw output to masm data bytes.
        ;
        ; We set button to ownerdraw so its not visible and only those that 
        ; know can click it and browse for a file to convert to masm data bytes
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDC_BTN_BIN2DBEX
            Invoke CDBrowseForFile, hWin, TRUE
            .IF eax == TRUE
                Invoke lstrcpy, Addr CDCompressedFileName, Addr CDFileName
                Invoke CDOpenFile, Addr CDCompressedFileName
                Invoke CDOutputAsmFile
                Invoke CDCloseFile
                
                Invoke CDJustFnameExt, Addr CDAsmFileName, Addr CDFileNameExtOnly
                Invoke lstrcpy, Addr szStatusBarMsg, Addr szFile
                Invoke lstrcat, Addr szStatusBarMsg, Addr CDFileNameExtOnly
                Invoke lstrcat, Addr szStatusBarMsg, Addr szSuccess
                Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szStatusBarMsg
            .ENDIF
            
        ;----------------------------------------------------------------------
        ; Compress Text Strings To Masm Data Bytes Output
        ;----------------------------------------------------------------------
        .ELSEIF eax == IDM_TEXT || eax == IDC_BTN_TEXT || eax == ACC_TEXT || eax == ACC_BTN_TEXT
            Invoke DialogBoxParam, hInstance, IDD_TEXTDLG, hWin, Addr CDTextDlgProc, NULL
            
        .ENDIF
        
    .ELSEIF eax == WM_CLOSE
        Invoke CDCloseFile
        Invoke DestroyWindow, hWin
        
    .ELSEIF eax == WM_DESTROY
        Invoke PostQuitMessage, NULL
		
	.ELSE
		Invoke DefWindowProc, hWin, uMsg, wParam, lParam ; rcx, edx, r8, r9
		ret
	.ENDIF
	xor rax, rax
	ret
WndProc endp

;------------------------------------------------------------------------------
; InitGUI - Initialize GUI: Bitmaps, Toolbar, Tooltips, Menu etc 
;------------------------------------------------------------------------------
InitGUI PROC FRAME hWin:QWORD
    LOCAL hMainMenu:QWORD
    LOCAL hBitmap:QWORD
    
    Invoke GetDlgItem, hWin, IDC_STATUSBAR
    mov hStatusBar, rax
    
    ;--------------------------------------------------------------------------
    ; Set main window icons 
    ;--------------------------------------------------------------------------
    Invoke SendMessage, hWin, WM_SETICON, ICON_BIG, hIcoMain
    Invoke SendMessage, hWin, WM_SETICON, ICON_SMALL, hIcoMain
    
    ;--------------------------------------------------------------------------
    ; Set default radio and checkbox selections and statusbar text
    ;--------------------------------------------------------------------------
    Invoke SendDlgItemMessage, hWin, IDC_RBN_XPRESS, BM_SETCHECK, BST_CHECKED, 0
    Invoke SendDlgItemMessage, hWin, IDC_CHK_ASM, BM_SETCHECK, BST_CHECKED, 0
    Invoke SendDlgItemMessage, hWin, IDC_CHK_ASMSEG, BM_SETCHECK, BST_CHECKED, 0
    Invoke SendMessage, hStatusBar, SB_SETTEXT, 0, Addr szInfo_XPRESS
    
    ;--------------------------------------------------------------------------
    ; Create tooltip control and enum child controls to set text for each
    ;--------------------------------------------------------------------------
    Invoke CreateWindowEx, NULL, Addr szTooltipsClass, NULL, TTS_ALWAYSTIP, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, hWin, NULL, hInstance, NULL
    mov hToolTip, rax
    Invoke SendMessage, hToolTip, TTM_SETMAXTIPWIDTH, 0, 350
    invoke SendMessage, hToolTip, TTM_SETDELAYTIME, TTDT_AUTOPOP, 12000
    Invoke EnumChildWindows, hWin, Addr InitTipsForEachChild, hWin
    
    ;--------------------------------------------------------------------------
    ; Button Bitmaps
    ;--------------------------------------------------------------------------
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_COMPRESS_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_COMPRESS_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_COMPRESS, BM_SETIMAGE, IMAGE_BITMAP, rax

    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_DECOMPRESS_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_DECOMPRESS_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_DECOMPRESS, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_EXIT_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_EXIT_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_EXIT, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_ABOUT_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_ABOUT_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_ABOUT, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_TEXT_WIDE
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_TEXT_WIDE
    ENDIF
    Invoke SendDlgItemMessage, hWin, IDC_BTN_TEXT, BM_SETIMAGE, IMAGE_BITMAP, rax
    
    ;--------------------------------------------------------------------------
    ; Main Menu Bitmaps
    ;--------------------------------------------------------------------------
    Invoke GetMenu, hWin
    mov hMainMenu, rax
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_COMPRESS_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_COMPRESS_MENU
    ENDIF
    mov hBitmap, rax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_FILE_OPEN_COMPRESS, MF_BYCOMMAND, hBitmap, 0   
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_DECOMPRESS_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_DECOMPRESS_MENU
    ENDIF
    mov hBitmap, rax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_FILE_OPEN_DECOMPRESS, MF_BYCOMMAND, hBitmap, 0 
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_EXIT_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_EXIT_MENU
    ENDIF
    mov hBitmap, rax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_FILE_EXIT, MF_BYCOMMAND, hBitmap, 0
    
    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_ABOUT_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_ABOUT_MENU
    ENDIF
    mov hBitmap, rax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_HELP_ABOUT, MF_BYCOMMAND, hBitmap, 0

    IFNDEF LZMA_RESOURCES
    Invoke LoadBitmap, hInstance, BMP_TEXT_MENU
    ELSE
    Invoke CDBitmapCreateFromCompressedRes, hInstance, LZMA_TEXT_MENU
    ENDIF
    mov hBitmap, rax
    Invoke SetMenuItemBitmaps, hMainMenu, IDM_TEXT, MF_BYCOMMAND, hBitmap, 0

    ret
InitGUI ENDP

;------------------------------------------------------------------------------
; InitTipsForEachChild - initialize tooltips for each control
;------------------------------------------------------------------------------
InitTipsForEachChild PROC FRAME USES RBX hChild:QWORD, lParam:QWORD
    LOCAL TooltipText[256]:BYTE
    LOCAL TooltipTextID:QWORD
    LOCAL tti:TTTOOLINFOA

    mov tti.cbSize, SIZEOF TTTOOLINFOA
    mov tti.uFlags, TTF_IDISHWND or TTF_SUBCLASS
    
    Invoke GetParent, hChild
    mov tti.hwnd, rax

    mov rax, hChild
    mov tti.uId, rax

    mov rax, hInstance
    mov tti.hinst, rax
    
    Invoke GetDlgCtrlID, hChild
    mov TooltipTextID, rax

    Invoke LoadString, hInstance, dword ptr TooltipTextID, Addr TooltipText, 256
    .IF rax == 0
        ; ignore controls we didnt set a tooltip text for in the stringtable
    .ELSE
        lea rax, TooltipText
        mov tti.lpszText, rax
        Invoke SendMessage, hToolTip, TTM_ADDTOOL, NULL, Addr tti
        Invoke SendMessage, hToolTip, TTM_ACTIVATE, TRUE, 0
    .ENDIF

    mov eax, TRUE
    ret
InitTipsForEachChild ENDP

;------------------------------------------------------------------------------
; CDOpenFile - Opens a file for compression or decompression
;
; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDOpenFile PROC FRAME lpszFilename:QWORD
    LOCAL hFile:QWORD
    LOCAL MemMapHandle:QWORD
    LOCAL MemMapPtr:QWORD
    LOCAL lpFileName:QWORD
    LOCAL qwFileSize:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDOpenFile'
    ENDIF

    ;--------------------------------------------------------------------------
    ; Some basic checks
    ;--------------------------------------------------------------------------
    .IF lpszFilename == NULL
        mov rax, FALSE
        ret
    .ENDIF
    Invoke lstrlen, lpszFilename
    .IF rax == 0 || rax > MAX_PATH
        mov rax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Check we dont have a file already opened, if so we close it first
    ;--------------------------------------------------------------------------
    .IF CDFileHandle != NULL ; we have a file opened already
        Invoke CDCloseFile
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Open file for read only or read/write access
    ;--------------------------------------------------------------------------
    Invoke CreateFile, lpszFilename, GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL
    .IF rax == INVALID_HANDLE_VALUE
        mov rax, FALSE
        ret
    .ENDIF
    mov hFile, rax ; store file handle

    ;--------------------------------------------------------------------------
    ; Get file size and verify its not too low or too high in size
    ;--------------------------------------------------------------------------
    Invoke GetFileSize, hFile, NULL
    .IF rax > 0FFFFFFFh ; 0FFFFFFFh = 256MB (268,435,455bytes) - 1FFFFFFFh = 536MB (536,870,911bytes)
        Invoke CloseHandle, hFile
        mov rax, FALSE
        ret
     .ENDIF
    mov qwFileSize, rax ; file size

    ;--------------------------------------------------------------------------
    ; Create file mapping of entire file
    ;--------------------------------------------------------------------------
    .IF qwFileSize > 0FFFFFFFh ; 0FFFFFFFh = 256MB (268,435,455bytes) - 1FFFFFFFh = 536MB (536,870,911bytes)
        Invoke CreateFileMapping, hFile, NULL, PAGE_READONLY, 0, 0FFFFFFFh, NULL
    .ELSE
        Invoke CreateFileMapping, hFile, NULL, PAGE_READONLY, 0, 0, NULL ; Create memory mapped file
    .ENDIF
    .IF rax == NULL
        Invoke CloseHandle, hFile
        mov rax, FALSE
        ret
    .ENDIF
    mov MemMapHandle, rax ; store mapping handle

    ;--------------------------------------------------------------------------
    ; Create view of file
    ;--------------------------------------------------------------------------
    Invoke MapViewOfFileEx, MemMapHandle, FILE_MAP_READ, 0, 0, 0, NULL
    .IF rax == NULL
        Invoke CloseHandle, MemMapHandle
        Invoke CloseHandle, hFile
        mov rax, FALSE
        ret
    .ENDIF
    mov MemMapPtr, rax ; store map view pointer
    
    ;--------------------------------------------------------------------------
    ; Save handles and file name
    ;--------------------------------------------------------------------------
    mov rax, hFile
    mov CDFileHandle, rax
    mov rax, MemMapHandle
    mov CDMemMapHandle, rax
    mov rax, MemMapPtr
    mov CDMemMapPtr, rax
    mov rax, qwFileSize
    mov CDFileSize, rax

    mov rax, TRUE
    ret
CDOpenFile ENDP

;------------------------------------------------------------------------------
; CDCloseFile - Closes a file opened with CDOpenFile
;
; Returns: Nothing
;------------------------------------------------------------------------------
CDCloseFile PROC FRAME

    .IF CDMemMapPtr != 0
        Invoke UnmapViewOfFile, CDMemMapPtr
    .ENDIF
    .IF CDMemMapHandle != 0
        Invoke CloseHandle, CDMemMapHandle
    .ENDIF
    .IF CDFileHandle != 0
        Invoke CloseHandle, CDFileHandle
    .ENDIF
    
    mov CDFileHandle, 0
    mov CDMemMapHandle, 0
    mov CDMemMapPtr, 0
    
    xor rax, rax
    ret
CDCloseFile ENDP

;------------------------------------------------------------------------------
; CDBrowseForFile - Browse for a file to open. Stores the selected file in CFFileName

; Returns: TRUE or FALSE
;------------------------------------------------------------------------------
CDBrowseForFile PROC FRAME hWin:QWORD, bCompress:QWORD
    LOCAL BrowseForFile:OPENFILENAME

    IFDEF DEBUG64
    PrintText 'CDBrowseForFile'
    ENDIF

    Invoke RtlZeroMemory, Addr BrowseForFile, SIZEOF OPENFILENAME
    
    mov BrowseForFile.lStructSize, SIZEOF OPENFILENAME
    mov rax, hWin
    mov BrowseForFile.hwndOwner, rax
    mov BrowseForFile.nMaxFile, MAX_PATH
    mov BrowseForFile.lpstrDefExt, 0
    .IF bCompress == TRUE
        lea rax, CDOpenCompressFileFilter
    .ELSE
        lea rax, CDOpenDecompressFileFilter
    .ENDIF
    mov BrowseForFile.lpstrFilter, rax
    mov BrowseForFile.Flags, OFN_EXPLORER or OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
    lea rax, CDFileName
    mov BrowseForFile.lpstrFile, rax
    Invoke GetOpenFileName, Addr BrowseForFile

    ; If user selected a file and didnt cancel browse operation...
    .IF rax != 0
        mov rax, TRUE
    .ELSE
        mov rax, FALSE
    .ENDIF
    ret
CDBrowseForFile ENDP

;------------------------------------------------------------------------------
; CDCompressFile - Compress an opened file to an output file using the compression 
; algorithm name as the extension. Stores a header signature at the first dword 
; indicating the compression algorithm used to compress the file data.
;
; Returns: TRUE or FALSE  
;------------------------------------------------------------------------------
CDCompressFile PROC FRAME
    LOCAL CompressorHandle:QWORD
    LOCAL CompressedBuffer:QWORD
    LOCAL CompressedBufferSize:QWORD
    LOCAL CompressedDataSize:QWORD
    LOCAL CompressionAlgorithm:QWORD
    LOCAL hFile:QWORD
    LOCAL BytesWritten:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDCompressFile'
    PrintString CDCompressedFileName
    ENDIF

    mov rax, CDAlgorithm
    .IF rax == 0
        mov rax, COMPRESS_ALGORITHM_XPRESS
    .ENDIF
    mov CompressionAlgorithm, rax
    
    ;--------------------------------------------------------------------------
    ; Construct output filename with extension based on algorithm used
    ;--------------------------------------------------------------------------
    Invoke lstrcpy, Addr CDCompressedFileName, Addr CDFileName
    mov rax, CompressionAlgorithm
    .IF rax == COMPRESS_ALGORITHM_MSZIP
        Invoke lstrcat, Addr CDCompressedFileName, Addr Ext_MSZIP
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS
        Invoke lstrcat, Addr CDCompressedFileName, Addr Ext_XPRESS
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke lstrcat, Addr CDCompressedFileName, Addr Ext_HUFF
    .ELSEIF rax == COMPRESS_ALGORITHM_LZMS
        Invoke lstrcat, Addr CDCompressedFileName, Addr Ext_LZMS
    .ELSE
        Invoke lstrcat, Addr CDCompressedFileName, Addr CDCompressedExt
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Create compressor
    ;--------------------------------------------------------------------------
    Invoke CreateCompressor, CompressionAlgorithm, NULL, Addr CompressorHandle ;COMPRESS_ALGORITHM_LZMS COMPRESS_ALGORITHM_XPRESS_HUFF
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDCompressFile CreateCompressor Failed'
        ENDIF
        mov rax, FALSE
        ret
    .ENDIF

    ;--------------------------------------------------------------------------
    ; Get size required first
    ;--------------------------------------------------------------------------
    Invoke Compress, CompressorHandle, CDMemMapPtr, CDFileSize, NULL, 0, Addr CompressedBufferSize
    .IF rax == FALSE
        Invoke GetLastError
        .IF rax == ERROR_INSUFFICIENT_BUFFER
            
        .ELSE
            IFDEF DEBUG64
            PrintText 'CDCompressFile Compress Get Size Failed'
            ENDIF
            .IF CompressorHandle != 0
                Invoke CloseCompressor, CompressorHandle
            .ENDIF
            mov rax, FALSE
            ret
        .ENDIF
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Alloc buffer required
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, CompressedBufferSize
    .IF rax == NULL
        IFDEF DEBUG64
        PrintText 'CDCompressFile GlobalAlloc Failed'
        ENDIF
        .IF CompressorHandle != 0
            Invoke CloseCompressor, CompressorHandle
        .ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    mov CompressedBuffer, rax
    
    ;--------------------------------------------------------------------------
    ; Do actual compression now
    ;--------------------------------------------------------------------------
    Invoke Compress, CompressorHandle, CDMemMapPtr, CDFileSize, CompressedBuffer, CompressedBufferSize, Addr CompressedDataSize
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDCompressFile Compress Failed'
        ENDIF
        .IF CompressedBuffer != 0
            Invoke GlobalFree, CompressedBuffer
        .ENDIF
        .IF CompressorHandle != 0
            Invoke CloseCompressor, CompressorHandle
        .ENDIF
        mov rax, FALSE
        ret
    .ENDIF

    ;--------------------------------------------------------------------------
    ; Create output file
    ;--------------------------------------------------------------------------
    Invoke CreateFile, Addr CDCompressedFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF rax == INVALID_HANDLE_VALUE
        IFDEF DEBUG64
        PrintText 'CDCompressFile CreateFile CDCompressedFileName Failed'
        ENDIF
        .IF CompressedBuffer != 0
            Invoke GlobalFree, CompressedBuffer
        .ENDIF
        .IF CompressorHandle != 0
            Invoke CloseCompressor, CompressorHandle
        .ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    mov hFile, rax
    
    ;--------------------------------------------------------------------------
    ; Write out header signature and then the compressed data to output file
    ;--------------------------------------------------------------------------
    mov rax, CompressionAlgorithm
    .IF rax == COMPRESS_ALGORITHM_MSZIP
        Invoke WriteFile, hFile, Addr HEADER_MSZIP, 4, Addr BytesWritten, NULL
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS
        Invoke WriteFile, hFile, Addr HEADER_XPRESS, 4, Addr BytesWritten, NULL
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke WriteFile, hFile, Addr HEADER_HUFF, 4, Addr BytesWritten, NULL
    .ELSEIF rax == COMPRESS_ALGORITHM_LZMS
        Invoke WriteFile, hFile, Addr HEADER_LZMS, 4, Addr BytesWritten, NULL
    .ENDIF

    Invoke WriteFile, hFile, CompressedBuffer, dword ptr CompressedDataSize, Addr BytesWritten, NULL
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    Invoke CloseHandle, hFile
    
    .IF CompressedBuffer != 0
        Invoke GlobalFree, CompressedBuffer
    .ENDIF
    
    .IF CompressorHandle != 0
        Invoke CloseCompressor, CompressorHandle
    .ENDIF
    
    mov eax, TRUE
    ret
CDCompressFile ENDP

;------------------------------------------------------------------------------
; CDDecompressFile - Decompress an opened file to an output file using the 
; compression algorithm found in the first dword value of the file. Output file 
; uses the extension of .raw so as to not overwrite any original files.
;
; Returns: TRUE or FALSE  
;------------------------------------------------------------------------------
CDDecompressFile PROC FRAME USES RBX 
    LOCAL DecompressorHandle:QWORD
    LOCAL DecompressedBuffer:QWORD
    LOCAL DecompressedBufferSize:QWORD
    LOCAL DecompressedDataSize:QWORD
    LOCAL DecompressionAlgorithm:QWORD
    LOCAL hFile:QWORD
    LOCAL pData:QWORD
    LOCAL FileSize:QWORD
    LOCAL BytesWritten:QWORD

    
    IFDEF DEBUG64
    PrintText 'CDDecompressFile'
    PrintString CDDecompressedFileName
    ENDIF
    
    ;--------------------------------------------------------------------------
    ; Construct output filename
    ;--------------------------------------------------------------------------
    Invoke lstrcpy, Addr CDDecompressedFileName, Addr CDFileName
    Invoke lstrcat, Addr CDDecompressedFileName, Addr CDDecompressedExt
    
    mov rax, CDAlgorithm
    .IF rax == 0
        mov rax, COMPRESS_ALGORITHM_XPRESS
    .ENDIF
    mov DecompressionAlgorithm, rax

    ;--------------------------------------------------------------------------
    ; Check for signature, if we find one, we set decompression algorithm 
    ; ourselves otherwise we assume the one the user specified and try that.
    ; adjust filesize and pointer to data to account for signature if found.
    ;--------------------------------------------------------------------------
    mov rbx, CDMemMapPtr
    mov eax, dword ptr [rbx]
    .IF eax == HEADER_MSZIP || eax == HEADER_XPRESS || eax == HEADER_HUFF || eax == HEADER_LZMS
        .IF eax == HEADER_MSZIP
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_MSZIP
        .ELSEIF eax == HEADER_XPRESS
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_XPRESS
        .ELSEIF eax == HEADER_HUFF
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_XPRESS_HUFF
        .ELSEIF eax == HEADER_LZMS
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_LZMS
        .ENDIF
        mov rax, CDMemMapPtr
        add rax, 4
        mov pData, rax
        mov rax, CDFileSize
        sub rax, 4
        mov FileSize, rax
    .ELSE
        mov rax, CDMemMapPtr
        mov pData, rax
        mov rax, CDFileSize
        mov FileSize, rax
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Create decompressor
    ;--------------------------------------------------------------------------
    Invoke CreateDecompressor, DecompressionAlgorithm, NULL, Addr DecompressorHandle ;COMPRESS_ALGORITHM_LZMS COMPRESS_ALGORITHM_XPRESS_HUFF
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDDecompressFile CreateDecompressor Failed'
        ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Get size required
    ;--------------------------------------------------------------------------
    Invoke Decompress, DecompressorHandle, pData, FileSize, NULL, 0, Addr DecompressedBufferSize
    .IF rax == FALSE
        Invoke GetLastError
        .IF rax == ERROR_INSUFFICIENT_BUFFER
            
        .ELSE
            IFDEF DEBUG64
            PrintText 'CDDecompressFile Decompress Get Size Failed'
            ENDIF
            .IF DecompressorHandle != 0
                Invoke CloseDecompressor, DecompressorHandle
            .ENDIF
            mov rax, FALSE
            ret
        .ENDIF
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Alloc buffer required
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, DecompressedBufferSize
    .IF rax == NULL
        IFDEF DEBUG64
        PrintText 'CDDecompressFile GlobalAlloc Failed'
        ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    mov DecompressedBuffer, rax
    
    ;--------------------------------------------------------------------------
    ; Do the actual decompression now
    ;--------------------------------------------------------------------------
    Invoke Decompress, DecompressorHandle, pData, FileSize, DecompressedBuffer, DecompressedBufferSize, Addr DecompressedDataSize
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDDecompressFile Decompress Failed'
        ENDIF
        .IF DecompressedBuffer != 0
            Invoke GlobalFree, DecompressedBuffer
        .ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Create output file and write data
    ;--------------------------------------------------------------------------
    Invoke CreateFile, Addr CDDecompressedFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF rax == INVALID_HANDLE_VALUE
        IFDEF DEBUG64
        PrintText 'CDDecompressFile CreateFile CDDecompressedFileName Failed'
        ENDIF
        .IF DecompressedBuffer != 0
            Invoke GlobalFree, DecompressedBuffer
        .ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    mov hFile, rax ; store file handle
    
    Invoke WriteFile, hFile, DecompressedBuffer, dword ptr DecompressedDataSize, Addr BytesWritten, NULL
    .IF rax == 0
        IFDEF DEBUG64
        PrintText 'CDDecompressFile WriteFile Failed'
        ENDIF
        Invoke CloseHandle, hFile
        
        .IF DecompressedBuffer != 0
            Invoke GlobalFree, DecompressedBuffer
        .ENDIF
        
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        
        mov rax, FALSE
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    Invoke CloseHandle, hFile
    
    .IF DecompressedBuffer != 0
        Invoke GlobalFree, DecompressedBuffer
    .ENDIF
    
    .IF DecompressorHandle != 0
        Invoke CloseDecompressor, DecompressorHandle
    .ENDIF
    
    mov rax, TRUE
    ret
CDDecompressFile ENDP

;------------------------------------------------------------------------------
; CDCompressMem - Compress data in memory with one of the Cabinet compression 
; algorithms. Stores a header signature at the first dword indicating the 
; compression algorithm used to compress the data.
;
; Returns: pointer to Compressed data if succesful or NULL otherwise.
; User should free memory when no longer required with call to GlobalFree 
; Variable pointed to by lpdwCompressedDataLength will contain the size of the
; compressed data or 0 if a failure occured.
;------------------------------------------------------------------------------
CDCompressMem PROC FRAME USES RBX lpUncompressedData:QWORD, qwUncompressedDataLength:QWORD, qwCompressionAlgorithm:QWORD, lpqwCompressedDataLength:QWORD
    LOCAL CompressorHandle:QWORD
    LOCAL CompressedBuffer:QWORD
    LOCAL CompressedBufferSize:QWORD
    LOCAL CompressedDataSize:QWORD
    LOCAL CompressionAlgorithm:QWORD
    LOCAL pData:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDCompressMem'
    ;PrintDec lpUncompressedData
    ;PrintDec dwUncompressedDataLength
    ENDIF
    
    .IF lpUncompressedData == NULL || qwUncompressedDataLength == 0
        IFDEF DEBUG64
        PrintText 'CDCompressMem lpUncompressedData == NULL || dwUncompressedDataLength == 0'
        ENDIF
        .IF lpqwCompressedDataLength != 0
            mov rbx, lpqwCompressedDataLength
            mov rax, 0
            mov [rbx], rax
        .ENDIF
        mov rax, NULL
        ret
    .ENDIF
    
    mov rax, qwCompressionAlgorithm
    .IF rax != COMPRESS_ALGORITHM_MSZIP && rax != COMPRESS_ALGORITHM_XPRESS && rax != COMPRESS_ALGORITHM_XPRESS_HUFF && rax != COMPRESS_ALGORITHM_LZMS
        IFDEF DEBUG64
        PrintText 'CDCompressMem dwCompressionAlgorithm Not Valid'
        ENDIF
        .IF lpqwCompressedDataLength != 0
            mov rbx, lpqwCompressedDataLength
            mov rax, 0
            mov [rbx], rax
        .ENDIF
        mov rax, NULL
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Create compressor
    ;--------------------------------------------------------------------------
    Invoke CreateCompressor, qwCompressionAlgorithm, NULL, Addr CompressorHandle
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDCompressMem CreateCompressor Failed'
        ENDIF
        .IF lpqwCompressedDataLength != 0
            mov rbx, lpqwCompressedDataLength
            mov rax, 0
            mov [rbx], rax
        .ENDIF
        mov rax, NULL
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Get size required first
    ;--------------------------------------------------------------------------
    Invoke Compress, CompressorHandle, lpUncompressedData, qwUncompressedDataLength, NULL, 0, Addr CompressedBufferSize
    .IF rax == FALSE
        Invoke GetLastError
        .IF rax == ERROR_INSUFFICIENT_BUFFER
            
        .ELSE
            IFDEF DEBUG64
            PrintText 'CDCompressMem Compress Get Size Failed'
            ENDIF
            .IF CompressorHandle != 0
                Invoke CloseCompressor, CompressorHandle
            .ENDIF
            .IF lpqwCompressedDataLength != 0
                mov rbx, lpqwCompressedDataLength
                mov rax, 0
                mov [rbx], rax
            .ENDIF
            mov rax, NULL
            ret
        .ENDIF
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Alloc buffer required
    ;--------------------------------------------------------------------------
    ;PrintDec CompressedBufferSize
    mov rax, CompressedBufferSize
    add rax, SIZEOF DWORD ; room for header signature
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, rax
    .IF rax == NULL
        IFDEF DEBUG64
        PrintText 'CDCompressMem GlobalAlloc Failed'
        ENDIF
        .IF CompressorHandle != 0
            Invoke CloseCompressor, CompressorHandle
        .ENDIF
        .IF lpqwCompressedDataLength != 0
            mov rbx, lpqwCompressedDataLength
            mov rax, 0
            mov [rbx], rax
        .ENDIF
        mov rax, NULL
        ret
    .ENDIF
    mov CompressedBuffer, rax
    mov pData, rax
    add pData, SIZEOF DWORD ; skip past header signature
    
    ;--------------------------------------------------------------------------
    ; Add header signature
    ;--------------------------------------------------------------------------
    mov rbx, CompressedBuffer
    mov rax, qwCompressionAlgorithm
    .IF rax == COMPRESS_ALGORITHM_MSZIP
        mov eax, HEADER_MSZIP
        mov dword ptr [rbx], eax
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS
        mov eax, HEADER_XPRESS
        mov dword ptr [rbx], eax
    .ELSEIF eax == COMPRESS_ALGORITHM_XPRESS_HUFF
        mov eax, HEADER_HUFF
        mov dword ptr [rbx], eax
    .ELSEIF eax == COMPRESS_ALGORITHM_LZMS
        mov eax, HEADER_LZMS
        mov dword ptr [rbx], eax
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Do actual compression now
    ;--------------------------------------------------------------------------
    Invoke Compress, CompressorHandle, lpUncompressedData, qwUncompressedDataLength, pData, CompressedBufferSize, Addr CompressedDataSize
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDCompressMem Compress Failed'
        ENDIF
        .IF CompressedBuffer != 0
            Invoke GlobalFree, CompressedBuffer
        .ENDIF
        .IF CompressorHandle != 0
            Invoke CloseCompressor, CompressorHandle
        .ENDIF
        .IF lpqwCompressedDataLength != 0
            mov rbx, lpqwCompressedDataLength
            mov rax, 0
            mov [rbx], rax
        .ENDIF
        mov rax, NULL
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    .IF CompressorHandle != 0
        Invoke CloseCompressor, CompressorHandle
    .ENDIF
    
    .IF lpqwCompressedDataLength != 0
        mov rbx, lpqwCompressedDataLength
        mov rax, CompressedDataSize
        add rax, SIZEOF DWORD ; to account for compression header we add
        mov [rbx], rax
    .ENDIF
    
    mov rax, CompressedBuffer
    ret
CDCompressMem ENDP

;------------------------------------------------------------------------------
; CDDecompressMem - Decompress memory that was previously compressed with one
; of the Cabinet compression algorithms. Checks for header signature first to 
; verify that there is a compressed data and what algorithm to use.
;
; Returns: pointer to decompressed data if succesful or NULL otherwise.
; User should free memory when no longer required with call to GlobalFree 
;------------------------------------------------------------------------------
CDDecompressMem PROC FRAME USES RBX lpCompressedData:QWORD, qwCompressedDataLength:QWORD
    LOCAL DecompressorHandle:QWORD
    LOCAL DecompressedBuffer:QWORD
    LOCAL DecompressedBufferSize:QWORD
    LOCAL DecompressedDataSize:QWORD
    LOCAL DecompressionAlgorithm:QWORD
    LOCAL pData:QWORD
    LOCAL nDataLength:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDDecompressMem'
    ENDIF
    
    .IF lpCompressedData == NULL || qwCompressedDataLength == 0
        mov rax, NULL
        ret
    .ENDIF
    
    ;--------------------------------------------------------------------------
    ; Check for header signature and adjust pointer and length
    ;--------------------------------------------------------------------------
    mov rbx, lpCompressedData
    mov eax, dword ptr [rbx]
    .IF eax == HEADER_MSZIP || eax == HEADER_XPRESS || eax == HEADER_HUFF || eax == HEADER_LZMS
        .IF eax == HEADER_MSZIP
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_MSZIP
        .ELSEIF eax == HEADER_XPRESS
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_XPRESS
        .ELSEIF eax == HEADER_HUFF
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_XPRESS_HUFF
        .ELSEIF eax == HEADER_LZMS
            mov DecompressionAlgorithm, COMPRESS_ALGORITHM_LZMS
        .ENDIF
    .ELSE
        mov rax, NULL
        ret
    .ENDIF
    mov rax, lpCompressedData
    add rax, 4 ; skip past header signature
    mov pData, rax
    
    mov rax, qwCompressedDataLength
    sub rax, 4 ; we need 4 less coz of signature
    .IF sqword ptr rax < 0 ; check size again
        mov rax, NULL
        ret
    .ENDIF
    mov nDataLength, rax
    
    ;--------------------------------------------------------------------------
    ; Create decompressor
    ;--------------------------------------------------------------------------
    Invoke CreateDecompressor, DecompressionAlgorithm, NULL, Addr DecompressorHandle
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDDecompressMem CreateDecompressor Failed'
        ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    IFDEF DEBUG64
    PrintText 'CDDecompressMem CreateDecompressor OK'
    ENDIF
    
    ;--------------------------------------------------------------------------
    ; Get size required
    ;--------------------------------------------------------------------------
    Invoke Decompress, DecompressorHandle, pData, nDataLength, NULL, 0, Addr DecompressedBufferSize
    .IF rax == FALSE
        Invoke GetLastError
        .IF rax == ERROR_INSUFFICIENT_BUFFER
            ; 
        .ELSE
            IFDEF DEBUG64
            PrintText 'CDDecompressMem Decompress Get Size Failed'
            ENDIF
            .IF DecompressorHandle != 0
                Invoke CloseDecompressor, DecompressorHandle
            .ENDIF
            mov rax, NULL
            ret
        .ENDIF
    .ENDIF
    IFDEF DEBUG64
    PrintText 'CDDecompressMem Decompress Size OK'
    ENDIF
    
    ;--------------------------------------------------------------------------
    ; Alloc buffer required
    ;--------------------------------------------------------------------------
    mov rax, DecompressedBufferSize 
    add rax, 4 ; we add four extra to give us 4 null bytes in case compressed
    ; data is an ansi or unicode string or something that requires null endings
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, rax ;DecompressedBufferSize
    .IF rax == NULL
        IFDEF DEBUG64
        PrintText 'CDDecompressMem GlobalAlloc Failed'
        ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov rax, NULL
        ret
    .ENDIF
    mov DecompressedBuffer, rax
    IFDEF DEBUG64
    PrintText 'CDDecompressMem GlobalAlloc OK'
    ENDIF
    
    ;--------------------------------------------------------------------------
    ; Do the actual decompression now
    ;--------------------------------------------------------------------------
    Invoke Decompress, DecompressorHandle, pData, nDataLength, DecompressedBuffer, DecompressedBufferSize, Addr DecompressedDataSize
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDDecompressMem Decompress Failed'
        ENDIF
        Invoke GetLastError
        .IF rax == ERROR_BAD_COMPRESSION_BUFFER
            IFDEF DEBUG64
            PrintText 'CDDecompressMem Decompress Failed ERROR_BAD_COMPRESSION_BUFFER'
            ENDIF
        .ELSEIF rax == ERROR_INSUFFICIENT_BUFFER
            IFDEF DEBUG64
            PrintText 'CDDecompressMem Decompress Failed ERROR_INSUFFICIENT_BUFFER'
            PrintDec DecompressedBufferSize
            PrintDec nDataLength
            PrintDec DecompressedBuffer
            PrintDec pData
            ENDIF
        .ELSEIF rax == ERROR_FUNCTION_FAILED
            IFDEF DEBUG64
            PrintText 'CDDecompressMem Decompress Failed ERROR_FUNCTION_FAILED'
            ENDIF
        .ELSEIF rax == ERROR_INVALID_HANDLE
            IFDEF DEBUG64
            PrintText 'CDDecompressMem Decompress Failed ERROR_INVALID_HANDLE'
            ENDIF
        .ENDIF
        .IF DecompressedBuffer != 0
            Invoke GlobalFree, DecompressedBuffer
        .ENDIF
        .IF DecompressorHandle != 0
            Invoke CloseDecompressor, DecompressorHandle
        .ENDIF
        mov rax, NULL
        ret
    .ENDIF
    IFDEF DEBUG64
    PrintText 'CDDecompressMem Decompress OK'
    ENDIF
    
    ;--------------------------------------------------------------------------
    ; Cleanup and return pointer to decompressed data
    ;--------------------------------------------------------------------------
    .IF DecompressorHandle != 0
        Invoke CloseDecompressor, DecompressorHandle
    .ENDIF
    IFDEF DEBUG64
    PrintText 'CDDecompressMem CloseDecompressor OK'
    ENDIF
    
    mov rax, DecompressedBuffer
    ret
CDDecompressMem ENDP

ALIGN 16
;------------------------------------------------------------------------------
; CDOutputAsmFile - Outputs the compressed file with an .asm extension using 
; masm style data bytes: 'DB 00Fh, 0A3h, 09Ch' for example - same as bin2dbex
;
; Returns: TRUE or FALSE  
;------------------------------------------------------------------------------
CDOutputAsmFile PROC FRAME USES RBX RDI RSI
    LOCAL pAsmData:QWORD
    LOCAL nAsmData:QWORD
    LOCAL LenDataAsm:QWORD
    LOCAL pRawData:QWORD
    LOCAL nRawData:QWORD
    LOCAL LenDataRaw:QWORD
    LOCAL MaxDataPos:QWORD
    LOCAL hFile:QWORD
    LOCAL BytesWritten:QWORD
    LOCAL nRows:QWORD
    LOCAL nCurrentRow:QWORD
    LOCAL nCurrentCol:QWORD
    LOCAL LenFileNameOnly:QWORD
    LOCAL LenFileNameExtOnly:QWORD
    LOCAL percentage:QWORD
    LOCAL ratio:QWORD
    LOCAL CDFileSizeUncompressed:QWORD
    LOCAL fad:WIN32_FILE_ATTRIBUTE_DATA
    LOCAL strAsciiAsmText[32]:BYTE

    ;--------------------------------------------------------------------------
    ; Construct asm output filename and create the output file
    ;--------------------------------------------------------------------------
    Invoke lstrcpy, Addr CDAsmFileName, Addr CDFileName
    Invoke lstrcat, Addr CDAsmFileName, Addr Ext_ASM
    
    ;--------------------------------------------------------------------------
    ; Get uncompressed file size without opening file
    ;--------------------------------------------------------------------------
    Invoke GetFileAttributesEx, Addr CDFileName, 0, Addr fad ; GetFileExInfoStandard is 0
    .IF rax == FALSE
        IFDEF DEBUG64
        PrintText 'CDOutputAsmFile GetFileAttributesEx Failed'
        ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    mov eax, fad.nFileSizeLow
    mov CDFileSizeUncompressed, rax

    IFDEF DEBUG64
    PrintText 'CDOutputAsmFile'
    PrintString CDAsmFileName
    ENDIF
    
    Invoke CDJustFname, Addr CDFileName, Addr CDFileNameOnly
    Invoke lstrlen, Addr CDFileNameOnly
    mov LenFileNameOnly, rax
    
    Invoke CDJustFnameExt, Addr CDFileName, Addr CDFileNameExtOnly
    Invoke lstrlen, Addr CDFileNameExtOnly
    mov LenFileNameExtOnly, rax
    
    ;--------------------------------------------------------------------------
    ; Create our output asm file
    ;--------------------------------------------------------------------------
    Invoke CreateFile, Addr CDAsmFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .IF rax == INVALID_HANDLE_VALUE
        IFDEF DEBUG64
        PrintText 'CDOutputAsmFile CreateFile CDOutputAsmFile Failed'
        ENDIF
        mov rax, FALSE
        ret
    .ENDIF
    mov hFile, rax
    
    mov rax, CDFileSize
    mov LenDataRaw, rax
    ;--------------------------------------------------------------------------
    ; Calc asm output length - could be neater, but its just guesstimates tbh
    ;--------------------------------------------------------------------------
    mov LenDataAsm, 0
    
    mov rax, 11 ; 13,10,'.DATA',13,10,13,10,0   = szASMData 
    add LenDataAsm, rax
    
    mov rax, LenFileNameOnly
    add rax, 4 ; ' \',13,10,0                   = szASMSlash
    add LenDataAsm, rax
    
    mov rax, CDFileSize
    shr rax, 4 ; / 16
    mov nRows, rax
    
    mov rax, 6 ; '0FFh, '                       = 6 bytes per raw byte output 
    mov rbx, CDFileSize ;nRows
    mul rbx
    add LenDataAsm, rax
    
    mov rax, nRows
    add rax, 1
    mov rbx, 6
    mul rbx
    add LenDataAsm, rax

    mov rax, LenFileNameOnly
    add LenDataAsm, rax
    add LenDataAsm, 16  ; szASMLength
    add LenDataAsm, rax
    add LenDataAsm, 4   ; 2 x CRLF
    add LenDataAsm, 164 ; 2 header lines + CRLFs
    add LenDataAsm, 54  ; Comment note
    add LenDataAsm, 115 ; Comment info text + CRLFs
    add LenDataAsm, 25  ; Max size for algo name
    mov rax, LenFileNameExtOnly
    add LenDataAsm, rax
    add LenDataAsm, 12  ; max of ascii size uncompressed
    add LenDataAsm, 12  ; max of ascii size compressed
    add LenDataAsm, 4   ; max of '100%' text
    add LenDataAsm, 16  ; ' Bytes' +CRLFs x 2
    add LenDataAsm, 4   ; % and CRLF
    add LenDataAsm, 8   ; (x:1) and CRLF
    add LenDataAsm, 16
    add LenDataAsm, 256
    and LenDataAsm, 0FFFFFFF0h
    
    ;--------------------------------------------------------------------------
    ; Alloc memory for asm hex output
    ;--------------------------------------------------------------------------
    Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, LenDataAsm
    .IF rax == NULL
        IFDEF DEBUG64
        PrintText 'CDOutputAsmFile GlobalAlloc Failed'
        ENDIF
        Invoke CloseHandle, hFile
        mov rax, FALSE
        ret
    .ENDIF
    mov pAsmData, rax
    
    mov rax, CDMemMapPtr
    mov pRawData, rax
    add rax, LenDataRaw
    mov MaxDataPos, rax
    
    ;--------------------------------------------------------------------------
    ; Output start
    ;--------------------------------------------------------------------------
    Invoke szUpper, Addr CDFileNameOnly
    
    Invoke lstrcpy, pAsmData, Addr szASMCmtLine
    Invoke lstrcat, pAsmData, Addr szASMCmtNote
    
    Invoke lstrcat, pAsmData, Addr szASMCmtOrigFile
    Invoke lstrcat, pAsmData, Addr CDFileNameExtOnly
    Invoke lstrcat, pAsmData, Addr szASMCFLF
    
    Invoke lstrcat, pAsmData, Addr szASMCmtSizeUncompressed
    Invoke qwtoa, CDFileSizeUncompressed, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr szASMBytes
    
    Invoke lstrcat, pAsmData, Addr szASMCmtSizeCompressed
    Invoke qwtoa, CDFileSize, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr szASMBytes
    
    ;--------------------------------------------------------------------------
    ; Calc percentage and ratio using fpu
    ;--------------------------------------------------------------------------
    Invoke lstrcat, pAsmData, Addr szASMCmtRatio
    finit
    fwait
    fld FP4(100.0)
    fidiv dword ptr CDFileSizeUncompressed
    fimul dword ptr CDFileSize
    fistp DWORD PTR percentage
    fstp st(0)
    
    fild dword ptr CDFileSizeUncompressed
    fidiv dword ptr CDFileSize
    fistp DWORD PTR ratio
    fstp st(0)
    
    mov rax, 100
    sub rax, percentage
    mov percentage, rax
    
    Invoke qwtoa, percentage, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr szASMPcnt
    Invoke qwtoa, ratio, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr strAsciiAsmText
    Invoke lstrcat, pAsmData, Addr szASMRatio
    ;--------------------------------------------------------------------------
    
    Invoke lstrcat, pAsmData, Addr szASMCmtAlgo
    mov rax, CDAlgorithm
    .IF rax == COMPRESS_ALGORITHM_MSZIP
        Invoke lstrcat, pAsmData, Addr szAlgorithmUsed_MSZIP
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS
        Invoke lstrcat, pAsmData, Addr szAlgorithmUsed_XPRESS
    .ELSEIF rax == COMPRESS_ALGORITHM_XPRESS_HUFF
        Invoke lstrcat, pAsmData, Addr szAlgorithmUsed_HUFF
    .ELSEIF rax == COMPRESS_ALGORITHM_LZMS
        Invoke lstrcat, pAsmData, Addr szAlgorithmUsed_LZMS
    .ENDIF
    Invoke lstrcat, pAsmData, Addr szASMCFLF

    Invoke lstrcat, pAsmData, Addr szASMCmtLine
    
    Invoke lstrcat, pAsmData, Addr szASMData
    Invoke lstrcat, pAsmData, Addr CDFileNameOnly
    Invoke lstrcat, pAsmData, Addr szASMSlash
    
    Invoke lstrlen, pAsmData
    mov nAsmData, rax
    
    IFDEF DEBUG64
    PrintText 'CDOutputAsmFile Loop start'
    ENDIF
    ;--------------------------------------------------------------------------
    ; Loop start
    ;--------------------------------------------------------------------------
    mov nCurrentRow, 0
    mov nCurrentCol, 0
    mov nRawData, 0
    mov rax, 0
    .WHILE rax < LenDataRaw
    
        mov rdi, pAsmData
        add rdi, nAsmData
        
        mov rsi, pRawData
        add rsi, nRawData
        
        ;----------------------------------------------------------------------
        ; Start of row
        ;----------------------------------------------------------------------
        .IF nCurrentCol == 0
            mov rax, nAsmData
            add rax, qwASMRowStartLength
            .IF rax < LenDataAsm
                Invoke RtlMoveMemory, rdi, Addr szASMRowStart, qwASMRowStartLength
                mov rax, qwASMRowStartLength
                add nAsmData, rax
            .ENDIF
            
            mov rdi, pAsmData
            add rdi, nAsmData
            
            mov rax, nAsmData
            add rax, qwASMhcs01stLength
            .IF rax < LenDataAsm
                Invoke RtlMoveMemory, rdi, Addr szASMhcs01st, qwASMhcs01stLength
                mov rax, qwASMhcs01stLength
                add nAsmData, rax
            .ENDIF
        .ENDIF
        
        ;----------------------------------------------------------------------
        ; Convert data byte to hex ascii
        ;----------------------------------------------------------------------
        mov rdi, pAsmData
        add rdi, nAsmData
        
        movzx rax, byte ptr [rsi]
        mov ah, al
        ror al, 4                   ; shift in next hex digit
        and al, 0FH                 ; get digit
        .IF al < 10
            add al, "0"             ; convert digits 0-9 to ascii
        .ELSE
            add al, ("A"-10)        ; convert digits 0Ah to 0Fh to uppercase ascii A-F
        .ENDIF
        mov byte ptr [rdi], al      ; store the asciihex(AL) in the string   
        inc rdi
        inc nAsmData
        mov al,ah
        
        and al, 0FH                 ; get digit
        .IF al < 10
            add al, "0"             ; convert digits 0-9 to ascii
        .ELSE
            add al, ("A"-10)        ; convert digits 0Ah to 0Fh to uppercase ascii A-F
        .ENDIF
        mov byte ptr [rdi], al      ; store the asciihex(AL) in the string   
        inc nAsmData
        
        ;----------------------------------------------------------------------
        ; Row Processing, split row every 16th column
        ;----------------------------------------------------------------------
        mov rdi, pAsmData
        add rdi, nAsmData
        
        inc nCurrentCol
        mov rax, nCurrentCol
        .IF rax == 16
            
            ;------------------------------------------------------------------
            ; End of Row
            ;------------------------------------------------------------------
            mov rax, nAsmData
            add rax, qwASMRowEndLength
            .IF rax < LenDataAsm
                Invoke RtlMoveMemory, rdi, Addr szASMRowEnd, qwASMRowEndLength
                mov rax, qwASMRowEndLength
                add nAsmData, rax
            .ENDIF
            
            mov nCurrentCol, 0
        .ELSE
        
            mov rax, nRawData
            inc rax
            .IF rax < LenDataRaw
                
                ;--------------------------------------------------------------
                ; Row Continues
                ;--------------------------------------------------------------
                mov rax, nAsmData
                add rax, qwASMhcs0Length
                .IF rax < LenDataAsm
                    Invoke RtlMoveMemory, rdi, Addr szASMhcs0, qwASMhcs0Length
                    mov rax, qwASMhcs0Length
                    add nAsmData, rax
                .ENDIF
            
            .ELSE
                ;--------------------------------------------------------------
                ; End of Data - Last Row End
                ;--------------------------------------------------------------
                mov rax, nAsmData
                add rax, qwASMRowEndLength
                .IF rax < LenDataAsm
                    Invoke RtlMoveMemory, rdi, Addr szASMRowEnd, qwASMRowEndLength
                    mov rax, qwASMRowEndLength
                    add nAsmData, rax
                .ENDIF
                
            .ENDIF
        
        .ENDIF
        
        ;----------------------------------------------------------------------
        ; Fetch next data byte to convert and loop again if < LenRawData
        ;----------------------------------------------------------------------
        inc nRawData
        mov rax, nRawData
    .ENDW
    
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr szASMCFLF, qwASMCFLFLength
    mov rax, qwASMCFLFLength
    add nAsmData, rax
    
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr CDFileNameOnly, LenFileNameOnly
    mov rax, LenFileNameOnly
    add nAsmData, rax
    
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr szASMLength, qwASMLengthLength
    mov rax, qwASMLengthLength
    add nAsmData, rax
    
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr CDFileNameOnly, LenFileNameOnly
    mov rax, LenFileNameOnly
    add nAsmData, rax
    
    mov rdi, pAsmData
    add rdi, nAsmData
    Invoke RtlMoveMemory, rdi, Addr szASMCFLF, qwASMCFLFLength
    mov rax, qwASMCFLFLength
    add nAsmData, rax
    
    Invoke WriteFile, hFile, pAsmData, dword ptr nAsmData, Addr BytesWritten, NULL
    .IF rax == 0
        IFDEF DEBUG64
        PrintText 'CDOutputAsmFile WriteFile Failed'
        ENDIF
    .ENDIF
    IFDEF DEBUG64
    PrintText 'CDOutputAsmFile WriteFile OK'
    ENDIF
    ;--------------------------------------------------------------------------
    ; Cleanup
    ;--------------------------------------------------------------------------
    Invoke FlushFileBuffers, hFile
    Invoke CloseHandle, hFile
    
    Invoke GlobalFree, pAsmData
    
    mov rax, TRUE
    ret
CDOutputAsmFile ENDP

;------------------------------------------------------------------------------
; CDBitmapCreateFromCompressedRes - Creates a bitmap from a compressed bitmap 
; resource (compressed with a Microsoft compression algorithm: XPRESS, XPRESS
; with Huffman encoding, MSZIP or LZMS) by uncompressing the data & creating a 
; bitmap from that data
;
; Calls: CDDecompressMem, CDBitmapCreateFromMem
;
; Returns: HBITMAP or NULL
;------------------------------------------------------------------------------
CDBitmapCreateFromCompressedRes PROC FRAME hInst:QWORD, qwResourceID:QWORD
    LOCAL hRes:QWORD
    LOCAL lpCompressedBitmapData:QWORD
    LOCAL qwCompressedBitmapDataLength:QWORD
    LOCAL lpDecompressedBitmapData:QWORD
    LOCAL hBitmap:QWORD
    
    IFDEF DEBUG64
    PrintText 'CDBitmapCreateFromCompressedRes'
    ENDIF
    
    Invoke FindResource, hInst, qwResourceID, RT_RCDATA ; get LZMS bitmap as raw data
    .IF rax != NULL
        mov hRes, rax
        Invoke SizeofResource, hInst, hRes
        .IF rax != 0
            mov qwCompressedBitmapDataLength, rax
            Invoke LoadResource, hInst, hRes
            .IF rax != NULL
                Invoke LockResource, rax
                .IF rax != NULL
                    mov lpCompressedBitmapData, rax
                    Invoke CDDecompressMem, lpCompressedBitmapData, qwCompressedBitmapDataLength
                    .IF rax != NULL
                        mov lpDecompressedBitmapData, rax
                        Invoke CDBitmapCreateFromMem, lpDecompressedBitmapData
                        .IF rax != NULL
                            mov hBitmap, rax
                            .IF lpDecompressedBitmapData != 0
                                Invoke GlobalFree, lpDecompressedBitmapData
                            .ENDIF
                            mov rax, hBitmap
                            ret
                        .ELSE
                            ;PrintText 'Failed to create bitmap from data'
                            .IF lpDecompressedBitmapData != 0
                                Invoke GlobalFree, lpDecompressedBitmapData
                            .ENDIF
                            mov rax, NULL
                        .ENDIF
                    .ELSE
                        ;PrintText 'Failed to decompress data'
                        mov rax, NULL
                    .ENDIF
                .ELSE
                    ;PrintText 'Failed to lock resource'
                    mov rax, NULL
                .ENDIF
            .ELSE
                ;PrintText 'Failed to load resource'
                mov rax, NULL
            .ENDIF
        .ELSE
            ;PrintText 'Failed to get resource size'
            mov rax, NULL
        .ENDIF
    .ELSE
        ;PrintText 'Failed to find resource'
        mov rax, NULL
    .ENDIF    
    
    ret
CDBitmapCreateFromCompressedRes ENDP

;------------------------------------------------------------------------------
; CDBitmapCreateFromCompressedMem - Creates a bitmap from a compressed bitmap 
; data stored in memory (compressed with a Microsoft compression algorithm: 
; XPRESS, XPRESS with Huffman encoding, MSZIP or LZMS) by uncompressing the 
; data & creating a bitmap from that data
;
; Calls: CDDecompressMem, CDBitmapCreateFromMem
;
; Returns: HBITMAP or NULL
;------------------------------------------------------------------------------
CDBitmapCreateFromCompressedMem PROC FRAME lpCompressedBitmapData:QWORD, qwCompressedBitmapDataLength:QWORD
    LOCAL lpDecompressedBitmapData:QWORD
    LOCAL hBitmap:QWORD

    .IF lpCompressedBitmapData == NULL || qwCompressedBitmapDataLength == 0
        mov rax, NULL
        ret
    .ENDIF
    
    Invoke CDDecompressMem, lpCompressedBitmapData, qwCompressedBitmapDataLength
    .IF rax != NULL
        mov lpDecompressedBitmapData, rax
        Invoke CDBitmapCreateFromMem, lpDecompressedBitmapData
        .IF rax != NULL
            mov hBitmap, rax
            .IF lpDecompressedBitmapData != 0
                Invoke GlobalFree, lpDecompressedBitmapData
            .ENDIF
            mov rax, hBitmap
            ret
        .ELSE
            ;PrintText 'Failed to create bitmap from data'
            .IF lpDecompressedBitmapData != 0
                Invoke GlobalFree, lpDecompressedBitmapData
            .ENDIF
        .ENDIF
    .ENDIF
    mov rax, NULL
    ret
CDBitmapCreateFromCompressedMem ENDP

;------------------------------------------------------------------------------
; CDBitmapCreateFromMem - Create a bitmap from bitmap data stored in memory 
;
; http://www.masmforum.com/board/index.php?topic=16267.msg134453#msg134453
;
; Returns: HBITMAP or NULL
;------------------------------------------------------------------------------
CDBitmapCreateFromMem PROC FRAME USES RCX RDX pBitmapData:QWORD
    LOCAL hDC:QWORD
    LOCAL hBmp:QWORD
    LOCAL lpInfoHeader:QWORD
    LOCAL lpInitBits:QWORD

    Invoke CreateDC, Addr szCDMemoryDisplayDC, NULL, NULL, NULL
    test rax, rax
    jz @f
    mov hDC, rax
    mov rdx, pBitmapData
    lea rcx, [rdx + SIZEOF BITMAPFILEHEADER]  ; start of the BITMAPINFOHEADER header
    mov lpInfoHeader, rcx
    xor rax, rax
    mov eax, dword ptr BITMAPFILEHEADER.bfOffBits[rdx]
    add rdx, rax
    mov lpInitBits, rdx
    Invoke  CreateDIBitmap, hDC, lpInfoHeader, CBM_INIT, lpInitBits, lpInfoHeader, DIB_RGB_COLORS
    mov hBmp, rax
    Invoke DeleteDC, hDC
    mov rax, hBmp
@@:
    ret
CDBitmapCreateFromMem ENDP

;------------------------------------------------------------------------------
; CDJustFname - Strip path name to just filename Without extention
;------------------------------------------------------------------------------
CDJustFname PROC FRAME USES RSI RDI szFilePathName:QWORD, szFileName:QWORD
    LOCAL LenFilePathName:QWORD
    LOCAL nPosition:QWORD
    
    Invoke szLen, szFilePathName
    mov LenFilePathName, rax
    mov nPosition, rax
    
    .IF LenFilePathName == 0
        mov rdi, szFileName
        mov byte ptr [rdi], 0
        mov rax, FALSE
        ret
    .ENDIF
    
    mov rsi, szFilePathName
    add rsi, rax
    
    mov rax, nPosition
    .WHILE rax != 0
        movzx rax, byte ptr [rsi]
        .IF al == '\' || al == ':' || al == '/'
            inc rsi
            .BREAK
        .ENDIF
        dec rsi
        dec nPosition
        mov rax, nPosition
    .ENDW
    mov rdi, szFileName
    mov rax, nPosition
    .WHILE rax != LenFilePathName
        movzx rax, byte ptr [rsi]
        .IF al == '.' ; stop here
            .BREAK
        .ENDIF
        mov byte ptr [rdi], al
        inc rdi
        inc rsi
        inc nPosition
        mov rax, nPosition
    .ENDW
    mov byte ptr [rdi], 0h
    mov rax, TRUE
    ret
CDJustFname ENDP

;------------------------------------------------------------------------------
; CDJustFnameExt - Strip path name to just filename with extention
;------------------------------------------------------------------------------
CDJustFnameExt PROC FRAME USES RSI RDI szFilePathName:QWORD, szFileName:QWORD
    LOCAL LenFilePathName:QWORD
    LOCAL nPosition:QWORD
    
    Invoke szLen, szFilePathName
    mov LenFilePathName, rax
    mov nPosition, rax
    
    .IF LenFilePathName == 0
        mov rdi, szFileName
        mov byte ptr [rdi], 0
        mov rax, FALSE
        ret
    .ENDIF
    
    mov rsi, szFilePathName
    add rsi, rax
    
    mov rax, nPosition
    .WHILE rax != 0
        movzx rax, byte ptr [rsi]
        .IF al == '\' || al == ':' || al == '/'
            inc rsi
            .BREAK
        .ENDIF
        dec rsi
        dec nPosition
        mov rax, nPosition
    .ENDW
    mov rdi, szFileName
    mov rax, nPosition
    .WHILE rax != LenFilePathName
        movzx rax, byte ptr [rsi]
        mov byte ptr [rdi], al
        inc rdi
        inc rsi
        inc nPosition
        mov rax, nPosition
    .ENDW
    mov byte ptr [rdi], 0h ; null out filename
    mov rax, TRUE
    ret
CDJustFnameExt  ENDP














end WinMainCRTStartup





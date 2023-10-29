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

; NOTE: Requires Masm64 Library: https://github.com/mrfearless/libraries/tree/master/Masm64

include windows.inc
include CommCtrl.inc
include shellapi.inc
include commdlg.inc
include masm64.inc      ; https://github.com/mrfearless/libraries/tree/master/Masm64

includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib
includelib shell32.lib
includelib comctl32.lib
includelib comdlg32.lib
includelib masm64.lib   ; https://github.com/mrfearless/libraries/tree/master/Masm64

include Cabinet.inc
includelib Cabinet.lib 


;------------------------------------------------------------------------------
; CD Prototypes
;------------------------------------------------------------------------------
WinMain                         PROTO hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
WndProc                         PROTO hWin:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
InitGUI                         PROTO hWin:QWORD
InitTipsForEachChild            PROTO hChild:QWORD, lParam:QWORD

; File Functions
CDOpenFile                      PROTO lpszFilename:QWORD
CDCloseFile                     PROTO
CDBrowseForFile                 PROTO hWin:QWORD, bCompress:QWORD

; Compression/Decompression Functions
CDCompressFile                  PROTO
CDDecompressFile                PROTO
CDCompressMem                   PROTO lpUncompressedData:QWORD, qwUncompressedDataLength:QWORD, qwCompressionAlgorithm:QWORD, lpqwCompressedDataLength:QWORD
CDDecompressMem                 PROTO lpCompressedData:QWORD, qwCompressedDataLength:QWORD

; Bitmap Create Functions
CDBitmapCreateFromCompressedMem PROTO lpCompressedBitmapData:QWORD, qwCompressedBitmapDataLength:QWORD
CDBitmapCreateFromCompressedRes PROTO hInst:QWORD, qwResourceID:QWORD
CDBitmapCreateFromMem           PROTO pBitmapData:QWORD

; Asm Function
CDOutputAsmFile                 PROTO

; Utility Functions
CDJustFname                     PROTO szFilePathName:QWORD, szFileName:QWORD
CDJustFnameExt                  PROTO szFilePathName:QWORD, szFileName:QWORD


.CONST
COMPRESS_ALGORITHM_INVALID      EQU 0
COMPRESS_ALGORITHM_NULL         EQU 1
COMPRESS_ALGORITHM_MSZIP        EQU 2 ; MSZIP compression algorithm
COMPRESS_ALGORITHM_XPRESS       EQU 3 ; XPRESS compression algorithm
COMPRESS_ALGORITHM_XPRESS_HUFF  EQU 4 ; XPRESS compression algorithm with Huffman encoding
COMPRESS_ALGORITHM_LZMS         EQU 5 ; LZMS compression algorithm 
COMPRESS_RAW                    EQU (1 SHL 29)

;------------------------------------------------------------------------------
; CD Constants
;------------------------------------------------------------------------------
; Icons & Bitmap Resource IDs:
ICO_MAIN                        EQU 100 ; 
BMP_COMPRESS_WIDE               EQU 101 ; Images/Compress_Button.bmp
BMP_DECOMPRESS_WIDE             EQU 102 ; Images/Decompress_Button.bmp
BMP_EXIT_WIDE                   EQU 103 ; Images/Exit_Button.bmp
BMP_ABOUT_WIDE                  EQU 104 ; Images/About_Button.bmp
BMP_COMPRESS_MENU               EQU 111 ; Images/Compress_Menu.bmp
BMP_DECOMPRESS_MENU             EQU 112 ; Images/Decompress_Menu.bmp
BMP_EXIT_MENU                   EQU 113 ; Images/Exit_Menu.bmp
BMP_ABOUT_MENU                  EQU 114 ; Images/About_Menu.bmp
BMP_TEXT_MENU                   EQU 115 ; Images/Text_Menu.bmp
BMP_TEXT_WIDE                   EQu 116 ; Images/Text_Button.bmp
LZMA_COMPRESS_WIDE              EQU 121 ; Images/Compress_Button.bmp.lzms
LZMA_DECOMPRESS_WIDE            EQU 122 ; Images/Decompress_Button.bmp.lzms
LZMA_EXIT_WIDE                  EQU 123 ; Images/Exit_Button.bmp.lzms
LZMA_ABOUT_WIDE                 EQU 124 ; Images/About_Button.bmp.lzms
LZMA_COMPRESS_MENU              EQU 131 ; Images/Compress_Menu.bmp.lzms
LZMA_DECOMPRESS_MENU            EQU 132 ; Images/Decompress_Menu.bmp.lzms
LZMA_EXIT_MENU                  EQU 133 ; Images/Exit_Menu.bmp.lzms
LZMA_ABOUT_MENU                 EQU 134 ; Images/About_Menu.bmp.lzms
LZMA_TEXT_MENU                  EQU 135 ; Images/Text_Menu.bmp.lzms
LZMA_TEXT_WIDE                  EQU 136 ; Images/Text_Button.bmp.lzms

; Accelerators:
ACCTABLE                        EQU 300
ACC_FILE_OPEN_COMPRESS          EQU 301 ; CTRL+C
ACC_FILE_OPEN_DECOMPRESS        EQU 302 ; CTRL+D
ACC_FILE_EXIT                   EQU 303 ; ALT+F4
ACC_HELP_ABOUT                  EQU 304 ; F1
ACC_TEXT                        EQU 305 ; CTRL+T
ACC_BTN_COMPRESS                equ 306 ; ALT+C
ACC_BTN_DECOMPRESS              equ 307 ; ALT+D
ACC_BTN_EXIT                    equ 308 ; ALT+X
ACC_BTN_PASTE                   equ 309 ; ALT+P
ACC_BTN_COPY                    equ 310 ; ALT+C
ACC_BTN_LOAD                    equ 311 ; ALT+L
ACC_BTN_SAVE                    equ 312 ; ALT+S
ACC_BTN_TEXT                    equ 313 ; ALT+T

;CD.dlg Resource IDs:
IDD_DIALOG                      EQU 1000
IDC_STC_INFO                    EQU 1001
IDC_RBN_XPRESS                  EQU 1002
IDC_RBN_XPRESS_HUFF             EQU 1003
IDC_RBN_MSZIP                   EQU 1004
IDC_RBN_LZMS                    EQU 1005
IDC_BTN_COMPRESS                EQU 1006
IDC_BTN_DECOMPRESS              EQU 1007
IDC_BTN_EXIT                    EQU 1008
IDC_STATUSBAR                   EQU 1009
IDC_CHK_ASM                     EQU 1010
IDC_SHP1                        EQU 1011
IDC_BTN_ABOUT                   EQU 1012
IDC_SHP2                        EQU 1013
IDC_BTN_BIN2DBEX                EQU 1014
IDC_CHK_ASMSEG                  EQU 1015
IDC_BTN_TEXT                    EQU 1016

; Main Menu Resource IDs:
IDM_MENU                        EQU 10000
IDM_FILE_OPEN_COMPRESS          EQU 10001
IDM_FILE_OPEN_DECOMPRESS        EQU 10002
IDM_FILE_CLOSE                  EQU 10003
IDM_TEXT                        EQU 10006
IDM_FILE_EXIT                   EQU 10004
IDM_HELP_ABOUT                  EQU 10101


.DATA
;------------------------------------------------------------------------------
; CD Initialized Data
;------------------------------------------------------------------------------
align 01
szCDMemoryDisplayDC             DB 'DISPLAY',0
ClassName                       DB 'DLGCLASS',0
AppName                         DB 'Compress-Decompress Utility',0
AboutMsg                        DB 'github.com/mrfearless',13,10,'Copyright © fearless 2023',0
szTooltipsClass                 DB 'Tooltips_class32',0

bAsmOutput                      DQ TRUE
bAsmDataSeg                     DQ TRUE

; Various Strings & Buffers
Ext_MSZIP                       DB ".mszp",0
Ext_XPRESS                      DB ".xprs",0
Ext_HUFF                        DB ".huff",0
Ext_LZMS                        DB ".lzms",0
Ext_ASM                         DB ".asm",0

CDCompressedExt                 DB ".xxx",0
CDDecompressedExt               DB ".raw",0
szCompressingFile               DB 'Compressing File: ',0
szDecompressingFile             DB 'Decompressing File: ',0
szCompressedFile                DB 'Compressed File: ',0
szDecompressedFile              DB 'Decompressed File: ',0
szSuccess                       DB ' - Success.',0
szFailure                       DB ' - Failure.',0
szFile                          DB 'File: ',0
szProcessingFile                DB 'Processing File: ',0
szMASMOutputFile                DB ' (MASM Output)',0
szPleaseWait                    DB ', please wait...',0

szInfo_XPRESS                   DB 'XPRESS: Medium Compression Ratio | High Decompression Speed | Low Mem Requirement',0
szInfo_HUFF                     DB 'Huffman: Medium Compression Ratio | Medium-High Decompression Speed | Low Mem Requirement',0
szInfo_MSZIP                    DB 'MSZIP: Medium-High Compression Ratio | High Decompression Speed | Medium Mem Requirement',0
szInfo_LZMS                     DB 'LZMS: High Compression Ratio | High Decompression Speed | Medium-High Mem Requirement',0

szCOMPRESS_ALGORITHM_MSZIP      DB 'COMPRESS_ALGORITHM_MSZIP',0
szCOMPRESS_ALGORITHM_XPRESS     DB 'COMPRESS_ALGORITHM_XPRESS',0 ; 25
szCOMPRESS_ALGORITHM_HUFF       DB 'COMPRESS_ALGORITHM_HUFF',0
szCOMPRESS_ALGORITHM_LZMS       DB 'COMPRESS_ALGORITHM_LZMS',0

szAlgorithmUsed_MSZIP           DB 'MSZIP',0
szAlgorithmUsed_XPRESS          DB 'XPRESS',0 ; 25
szAlgorithmUsed_HUFF            DB 'XPRESS with Huffman',0
szAlgorithmUsed_LZMS            DB 'LZMS',0

CDFileName                      DB MAX_PATH DUP (0)
CDCompressedFileName            DB MAX_PATH DUP (0)
CDDecompressedFileName          DB MAX_PATH DUP (0)
CDAsmFileName                   DB MAX_PATH DUP (0)
CDFileNameOnly                  DB MAX_PATH DUP (0)
CDFileNameExtOnly               DB MAX_PATH DUP (0)
CDFileNameExtOnlyOutput         DB MAX_PATH DUP (0)
szStatusBarMsg                  DB 512 DUP (0)

; Browse For File File Filters
CDOpenCompressFileFilter        DB "All Files (*.*)",0,"*.*",0
                                DB "Image Files (*.bmp,*.ico,*.png,*.gif,*.jpg,*.jpeg)",0,"*.bmp;*.ico;*.png;*.gif;*.jpg;*.jpeg",0
                                DB "Document Files (*.doc,*.txt,*.md)",0,"*.doc;*.txt;*.md",0
                                DB "Binary Files (*.exe,*.dll)",0,"*.exe;*.dll",0
                                DB "Archive Files (*.zip,*.rar,*.7z)",0,"*.zip;*.rar;*.7z",0
                                DB 0

CDOpenDecompressFileFilter      DB "CD Files (*.mszp,*.xprs,*.huff,*.lzms)",0,"*.mszp;*.xprs;*.huff;*.lzms",0
                                DB "All Files (*.*)",0,"*.*",0
                                DB 0

; File stuff
CDFileHandle                    DQ 0
CDMemMapHandle                  DQ 0
CDMemMapPtr                     DQ 0
CDFileSize                      DQ 0
CDAlgorithm                     DQ COMPRESS_ALGORITHM_XPRESS

; Signatures
HEADER_MSZIP                    DD 'PZSM' ; 'MSZP'
HEADER_XPRESS                   DD 'SRPX' ; 'XPRS'
HEADER_HUFF                     DD 'FFUH' ; 'HUFF'
HEADER_LZMS                     DD 'SMZL' ; 'LZMS'

szHEADER_MSZIP                  DB 'MSZP',0
szHEADER_XPRESS                 DB 'XPRS',0
szHEADER_HUFF                   DB 'HUFF',0
szHEADER_LZMS                   DB 'LZMS',0

; Output of asm related strings
szASMhcs0                       DB 'h, 0',0 ; h comma space zero - used for asm output - 4
qwASMhcs0Length                 DQ ($ - szASMhcs0) -1
szASMhcs01st                    DB '0',0 ; first - 1
qwASMhcs01stLength              DQ ($ - szASMhcs01st) -1
szASMhcs0Lst                    DB 'h',0 ; last - 1
qwASMhcs0LstLength              DQ ($ - szASMhcs0Lst) -1
szASMRowStart                   DB 'DB ',0 ; - 3
qwASMRowStartLength             DQ ($ - szASMRowStart) -1
szASMRowEnd                     DB 'h',13,10,0 ; - 3
qwASMRowEndLength               DQ ($ - szASMRowEnd) -1
szASMSlash                      DB ' \',13,10,0 ; - 4
qwASMSlashLength                DQ ($ - szASMSlash) -1
szASMConst                      DB 13,10,'.CONST',13,10,13,10,0 ; - 11
szASMData                       DB 13,10,'.DATA',13,10,13,10,0 ; - 11
szASMLength                     DB "Length DD $ - ",0 ; 16
qwASMLengthLength               DQ ($ - szASMLength) -1
szASMCFLF                       DB 13,10,0
qwASMCFLFLength                 DQ ($ - szASMCFLF) -1
szASMCmtLine                    DB ";------------------------------------------------------------------------------",13,10,0 ; - 82 x 2
szASMCmtNote                    DB "; CD - Compress-Decompress Utility by fearless",13,10,";",13,10,0 ; - 52
szASMCmtOrigFile                DB "; Source Filename  : ",0 ; - 21
szASMCmtSizeUncompressed        DB "; Size Uncompressed: ",0 ; - 21
szASMCmtSizeCompressed          DB "; Size Compressed  : ",0 ; - 21
szASMCmtAlgo                    DB "; Algorithm Used   : ",0 ; - 21
szASMCmtRatio                   DB "; Compression Ratio: ",0 ; - 21
szASMBytes                      DB " Bytes",13,10,0 ; 8 x 2
szASMPcnt                       DB "% (",0 ; 4
szASMRatio                      DB ":1)",13,10,0
szASMTextStart                  DB " ; (",0
qwASMTextStartLength            DQ ($ - szASMTextStart) -1
szASMTextMiddle                 DB " Bytes >> ",0
qwASMTextMiddleLength           DQ ($ - szASMTextMiddle) -1
szASMTextEnd                    DB " Bytes)",0
qwASMTextEndLength              DQ ($ - szASMTextEnd) -1

.DATA?
;------------------------------------------------------------------------------
; CD Uninitialized Data
;------------------------------------------------------------------------------
align 08
icc                             INITCOMMONCONTROLSEX <>
hInstance                       DQ ?
CommandLine                     DQ ?
hAcc                            DQ ?
hWnd                            DQ ?
hStatusBar                      DQ ?
hToolTip                        DQ ?
hIcoMain                        DQ ?








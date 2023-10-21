;------------------------------------------------------------------------------
; CD - Compress-Decompress Utility using MS Compression Api (Cabinet.dll) 
; fearles 2023 - github.com/mrfearless
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
; CD.EXE 57.0 KB (58,368 bytes) without LZMA resources (normal bitmap resources)
;
; About_Button.bmp            6.05 KB (6,198 bytes)
; About_Menu.bmp              1.61 KB (1,654 bytes)
; Compress_Button.bmp         6.05 KB (6,198 bytes)
; Compress_Menu.bmp           1.05 KB (1,078 bytes)
; Decompress_Button.bmp       6.05 KB (6,198 bytes)
; Decompress_Menu.bmp         1.05 KB (1,078 bytes)
; Exit_Button.bmp             6.05 KB (6,198 bytes)
; Exit_Menu.bmp               1.05 KB (1,078 bytes)
;                             ---------------------
;                            28.90 KB (29,680 bytes)
;
;
; CD.EXE 31.0 KB (31,744 bytes) with LZMA resources (RC_DATA lzma files)
;
; About_Button.bmp.lzms       0.36 KB (366 Bytes)
; About_Menu.bmp.lzms         0.26 KB (262 Bytes)
; Compress_Button.bmp.lzms    0.42 KB (426 Bytes)
; Compress_Menu.bmp.lzms      0.30 KB (304 Bytes)
; Decompress_Button.bmp.lzms  0.35 KB (352 Bytes)
; Decompress_Menu.bmp.lzms    0.27 KB (272 Bytes)
; Exit_Button.bmp.lzms        0.33 KB (332 Bytes)
; Exit_Menu.bmp.lzms          0.36 KB (366 Bytes)
;                             ---------------------
;                             2.61 KB (2,680 bytes)
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

include windows.inc
include user32.inc
include kernel32.inc
include gdi32.inc
include shell32.inc
include comctl32.inc
include comdlg32.inc
include masm32.inc

includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib
includelib shell32.lib
includelib comctl32.lib
includelib comdlg32.lib
includelib masm32.lib

include Cabinet.inc
includelib Cabinet.lib 

;------------------------------------------------------------------------------
; CD Prototypes
;------------------------------------------------------------------------------
WinMain                         PROTO hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
WndProc                         PROTO hWin:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
InitGUI                         PROTO hWin:DWORD
InitTipsForEachChild            PROTO hChild:DWORD, lParam:DWORD

; File Functions
CDOpenFile                      PROTO lpszFilename:DWORD
CDCloseFile                     PROTO
CDBrowseForFile                 PROTO hWin:DWORD, bCompress:DWORD

; Compression/Decompression Functions
CDCompressFile                  PROTO
CDDecompressFile                PROTO
CDDecompressMem                 PROTO lpCompressedData:DWORD, dwCompressedDataLength:DWORD

; Bitmap Create Functions
CDBitmapCreateFromCompressedMem PROTO lpCompressedBitmapData:DWORD, dwCompressedBitmapDataLength:DWORD
CDBitmapCreateFromCompressedRes PROTO hInst:DWORD, dwResourceID:DWORD
CDBitmapCreateFromMem           PROTO pBitmapData:DWORD

; Asm Function
CDOutputAsmFile                 PROTO

; Utility Functions
CDRawToHexString                PROTO lpRaw:DWORD, lpRawMax:DWORD, dwRawSize:DWORD, lpszAsciiHexString:DWORD, bUpperCase:DWORD, bByteSwap:DWORD
CDJustFname                     PROTO szFilePathName:DWORD, szFileName:DWORD
CDJustFnameExt                  PROTO szFilePathName:DWORD, szFileName:DWORD


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
LZMA_COMPRESS_WIDE              EQU 121 ; Images/Compress_Button.bmp.lzms
LZMA_DECOMPRESS_WIDE            EQU 122 ; Images/Decompress_Button.bmp.lzms
LZMA_EXIT_WIDE                  EQU 123 ; Images/Exit_Button.bmp.lzms
LZMA_ABOUT_WIDE                 EQU 124 ; Images/About_Button.bmp.lzms
LZMA_COMPRESS_MENU              EQU 131 ; Images/Compress_Menu.bmp.lzms
LZMA_DECOMPRESS_MENU            EQU 132 ; Images/Decompress_Menu.bmp.lzms
LZMA_EXIT_MENU                  EQU 133 ; Images/Exit_Menu.bmp.lzms
LZMA_ABOUT_MENU                 EQU 134 ; Images/About_Menu.bmp.lzms


; Accelerators:
ACCTABLE                        EQU 300
ACC_FILE_OPEN_COMPRESS          EQU 301 ; CTRL+C
ACC_FILE_OPEN_DECOMPRESS        EQU 302 ; CTRL+D
ACC_FILE_EXIT                   EQU 303 ; ALT+F4
ACC_HELP_ABOUT                  EQU 304 ; F1

;CD.dlg Resource IDs:
IDD_DIALOG                      EQU 1000
IDC_STC_INFO                    EQU 1001 ; TipID = 2001
IDC_RBN_XPRESS                  EQU 1002 ; TipID = 2002 
IDC_RBN_XPRESS_HUFF             EQU 1003 ; TipID = 2003
IDC_RBN_MSZIP                   EQU 1004 ; TipID = 2004
IDC_RBN_LZMS                    EQU 1005 ; TipID = 2005
IDC_BTN_COMPRESS                EQU 1006 ; TipID = 2006
IDC_BTN_DECOMPRESS              EQU 1007 ; TipID = 2007
IDC_BTN_EXIT                    EQU 1008 ; TipID = 2008
IDC_STATUSBAR                   EQU 1009 ; TipID = 2009
IDC_CHK_ASM                     EQU 1010 ; TipID = 2010
IDC_SHP1                        EQU 1011 ; TipID = 2011
IDC_BTN_ABOUT                   EQU 1012 ; TipID = 2012
IDC_SHP2                        EQU 1013 ; TipID = 2013
IDC_BTN_BIN2DBEX                EQU 1014 ; TipID = 2013

; Main Menu Resource IDs:
IDM_MENU                        EQU 10000
IDM_FILE_OPEN_COMPRESS          EQU 10001
IDM_FILE_OPEN_DECOMPRESS        EQU 10002
IDM_FILE_CLOSE                  EQU 10003
IDM_FILE_EXIT                   EQU 10004
IDM_HELP_ABOUT                  EQU 10101


.DATA
;------------------------------------------------------------------------------
; CD Initialized Data
;------------------------------------------------------------------------------
szCDMemoryDisplayDC             DB 'DISPLAY',0
ClassName                       DB 'DLGCLASS',0
AppName                         DB 'Compress-Decompress Utility',0
AboutMsg                        DB 'github.com/mrfearless',13,10,'Copyright © fearless 2023',0

bAsmOutput                      DD TRUE

; Various Strings & Buffers
Ext_MSZIP                       DB ".mszp",0
Ext_XPRESS                      DB ".xprs",0
Ext_HUFF                        DB ".huff",0
Ext_LZMS                        DB ".lzms",0
Ext_ASM                         DB ".asm",0

CDCompressedExt                 DB ".xxx",0
CDDecompressedExt               DB ".raw",0
szCompressFile                  DB 'Compressed File: ',0
szDecompressFile                DB 'Decompressed File: ',0
szSuccess                       DB ' - Success.',0
szFailure                       DB ' - Failure.',0
szFile                          DB 'File: ',0

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
CDFileHandle                    DD 0
CDMemMapHandle                  DD 0
CDMemMapPtr                     DD 0
CDFileSize                      DD 0
CDAlgorithm                     DD COMPRESS_ALGORITHM_XPRESS

; Signatures
HEADER_MSZIP                    DD 'PZSM' ; 'MSZP'
HEADER_XPRESS                   DD 'SRPX' ; 'XPRS'
HEADER_HUFF                     DD 'FFUH' ; 'HUFF'
HEADER_LZMS                     DD 'SMZL' ; 'LZMS'

; Output of asm related strings
szASMhcs0                       DB 'h, 0',0 ; h comma space zero - used for asm output - 4
szASMhcs01st                    DB '0',0 ; first - 1
szASMhcs0Lst                    DB 'h',0 ; last - 1
szASMRowStart                   DB 'DB ',0 ; - 3
szASMRowEnd                     DB 'h',13,10,0 ; - 3
szASMSlash                      DB ' \',13,10,0 ; - 4
szASMData                       DB 13,10,'.DATA',13,10,13,10,0 ; - 11
szASMLength                     DB "Length DD $ - ",0 ; 16
szASMCFLF                       DB 13,10,0
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


.DATA?
;------------------------------------------------------------------------------
; CD Uninitialized Data
;------------------------------------------------------------------------------
icc                             INITCOMMONCONTROLSEX <>
hInstance                       DD ?
CommandLine                     DD ?
hAcc                            DD ?
hWnd                            DD ?
hStatusBar                      DD ?
hToolTip                        DD ?
hIcoMain                        DD ?




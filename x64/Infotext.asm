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
; 2) Adding LZMS compressed bitmap files (.lzms) as resources which are 
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
; The data below is compressed MSZIP data in masm data bytes (szMSZPText)
; It is shown in the about dialog in an edit control as an example of using a 
; compressed string.
;------------------------------------------------------------------------------

.DATA

szMSZPText \
DB 04Dh, 053h, 05Ah, 050h, 00Ah, 051h, 0E5h, 0C0h, 018h, 000h, 0A2h, 002h, 0F9h, 008h, 000h, 000h
DB 000h, 000h, 000h, 000h, 0F9h, 008h, 000h, 000h, 000h, 000h, 000h, 000h, 0EBh, 003h, 000h, 000h
DB 043h, 04Bh, 095h, 056h, 04Dh, 06Fh, 0DBh, 038h, 010h, 0BDh, 01Bh, 0F0h, 07Fh, 098h, 05Bh, 01Ah
DB 040h, 0D1h, 036h, 0EEh, 076h, 0D3h, 0CDh, 02Dh, 0B0h, 0B7h, 068h, 0B0h, 04Dh, 0D7h, 0A8h, 0B7h
DB 068h, 090h, 01Bh, 025h, 051h, 016h, 051h, 091h, 014h, 044h, 02Ah, 0B6h, 0F2h, 0EBh, 0F7h, 00Dh
DB 029h, 0CBh, 072h, 03Eh, 00Eh, 06Bh, 0C4h, 0B0h, 044h, 072h, 0BEh, 0DEh, 0BCh, 037h, 0CCh, 0BFh
DB 095h, 0A4h, 0D2h, 0D6h, 0B5h, 0DDh, 029h, 0B3h, 025h, 02Fh, 0F7h, 09Eh, 076h, 0C2h, 051h, 06Eh
DB 075h, 0D3h, 04Ah, 0E7h, 064h, 041h, 09Dh, 00Bh, 03Bh, 038h, 077h, 0B7h, 079h, 0B8h, 05Dh, 08Fh
DB 05Bh, 0CAh, 01Ah, 012h, 0F5h, 0D6h, 0B6h, 0CAh, 057h, 09Ah, 084h, 029h, 0A8h, 090h, 013h, 033h
DB 065h, 048h, 04Bh, 06Dh, 0DBh, 09Eh, 032h, 059h, 0DAh, 056h, 052h, 0A1h, 05Ch, 053h, 08Bh, 09Eh
DB 09Dh, 029h, 09Fh, 012h, 007h, 086h, 0EDh, 056h, 019h, 051h, 093h, 053h, 04Fh, 078h, 02Bh, 043h
DB 014h, 05Fh, 029h, 017h, 013h, 0C1h, 0EFh, 022h, 059h, 0FCh, 079h, 045h, 059h, 0EFh, 0A5h, 04Bh
DB 028h, 0EBh, 0FCh, 034h, 031h, 015h, 04Eh, 088h, 0A6h, 069h, 0EDh, 05Eh, 069h, 0E1h, 065h, 0DDh
DB 0D3h, 065h, 0F2h, 0FEh, 0C3h, 0C7h, 078h, 03Eh, 0A5h, 0F9h, 06Ch, 03Eh, 05Bh, 0D7h, 052h, 038h
DB 049h, 0C6h, 07Ah, 0F6h, 02Ch, 08Eh, 00Eh, 0C6h, 072h, 0C3h, 02Ah, 01Ch, 0D5h, 058h, 0E4h, 017h
DB 043h, 08Bh, 08Fh, 07Fh, 044h, 017h, 0A4h, 045h, 0CFh, 0A6h, 028h, 081h, 06Ch, 0E3h, 011h, 0A4h
DB 00Eh, 085h, 06Ah, 0B5h, 0ADh, 03Ch, 021h, 06Eh, 0D1h, 0E5h, 092h, 004h, 035h, 0D6h, 0B6h, 027h
DB 0B8h, 0B4h, 0C2h, 02Bh, 09Bh, 0D0h, 00Eh, 0D0h, 090h, 0EDh, 07Ch, 0D3h, 04Dh, 0C2h, 058h, 0B3h
DB 095h, 06Dh, 00Ch, 0E4h, 0A7h, 018h, 084h, 064h, 002h, 010h, 099h, 0E4h, 0E4h, 08Eh, 095h, 0A6h
DB 05Ch, 0C8h, 072h, 045h, 017h, 0B4h, 01Ch, 0D6h, 02Eh, 056h, 023h, 0D4h, 0F4h, 0C3h, 0ABh, 05Ah
DB 0F9h, 07Eh, 0E8h, 0D3h, 0DDh, 066h, 03Ch, 0C4h, 089h, 0DCh, 0ACh, 06Fh, 001h, 043h, 029h, 045h
DB 01Bh, 0CAh, 05Bh, 0BCh, 05Fh, 07Ch, 080h, 09Bh, 02Dh, 0F2h, 0EAh, 0B2h, 014h, 02Eh, 07Eh, 0D3h
DB 0EDh, 061h, 073h, 008h, 0D2h, 039h, 0E9h, 062h, 0B7h, 055h, 0DEh, 05Ah, 067h, 04Bh, 0FFh, 0C2h
DB 0A1h, 0B7h, 063h, 072h, 048h, 07Fh, 0D2h, 076h, 02Ah, 084h, 017h, 043h, 022h, 0D6h, 08Ch, 01Dh
DB 02Dh, 06Dh, 0D7h, 092h, 0EBh, 09Ah, 0C6h, 0B6h, 01Eh, 07Dh, 07Bh, 095h, 040h, 0EEh, 09Ah, 0EEh
DB 0D7h, 0DFh, 0FFh, 0DAh, 06Ch, 092h, 0E1h, 037h, 082h, 0F7h, 0A5h, 02Bh, 04Bh, 00Dh, 0A4h, 0A4h
DB 0C9h, 06Dh, 001h, 0B7h, 0C9h, 040h, 042h, 084h, 0FDh, 0FAh, 070h, 0B7h, 009h, 0C8h, 004h, 00Ah
DB 02Bh, 094h, 030h, 025h, 047h, 0D6h, 053h, 028h, 026h, 072h, 0D7h, 082h, 002h, 0AFh, 087h, 0C5h
DB 0A3h, 0B3h, 0E4h, 03Ch, 033h, 054h, 000h, 0FEh, 0ADh, 011h, 0BEh, 0C3h, 0F3h, 0EAh, 0E7h, 03Fh
DB 0DFh, 057h, 0F4h, 028h, 0EAh, 00Eh, 0EBh, 011h, 090h, 04Ah, 08Ah, 002h, 09Dh, 013h, 03Eh, 0BCh
DB 039h, 02Fh, 05Ah, 03Fh, 056h, 088h, 0F0h, 04Ch, 069h, 0F4h, 017h, 07Fh, 070h, 018h, 0BAh, 0CDh
DB 03Bh, 081h, 09Eh, 04Dh, 0ABh, 040h, 0CFh, 037h, 094h, 093h, 0A3h, 03Ch, 0F0h, 0ABh, 0E3h, 0ACh
DB 021h, 094h, 060h, 075h, 084h, 014h, 067h, 00Fh, 0EDh, 00Fh, 099h, 06Ah, 0F1h, 00Bh, 085h, 0E2h
DB 0F0h, 021h, 074h, 0FEh, 0B2h, 039h, 0B1h, 09Ah, 04Ch, 079h, 02Dh, 01Ah, 0C2h, 01Eh, 0E0h, 0CFh
DB 061h, 084h, 032h, 018h, 0B3h, 029h, 04Ah, 0DCh, 0AFh, 020h, 045h, 0AEh, 01Eh, 05Fh, 0BFh, 0B3h
DB 090h, 07Fh, 0EFh, 058h, 0BDh, 0BBh, 04Ah, 0E5h, 015h, 01Dh, 019h, 021h, 04Eh, 0C4h, 037h, 078h
DB 067h, 007h, 0D7h, 041h, 068h, 097h, 0E7h, 074h, 01Bh, 019h, 02Dh, 032h, 050h, 09Eh, 032h, 0BBh
DB 04Fh, 0B8h, 00Bh, 09Dh, 039h, 051h, 05Ch, 025h, 0A7h, 0A6h, 087h, 0D9h, 090h, 0B7h, 012h, 08Ah
DB 039h, 0DDh, 01Fh, 007h, 048h, 09Ch, 015h, 0CFh, 053h, 09Fh, 07Ah, 061h, 0CCh, 0B9h, 0E6h, 082h
DB 06Bh, 044h, 063h, 0BCh, 0CAh, 0D1h, 0ADh, 0FDh, 020h, 062h, 015h, 0D3h, 05Ah, 0AEh, 02Eh, 017h
DB 09Fh, 0F6h, 0FCh, 0FDh, 03Dh, 0CDh, 074h, 093h, 00Ah, 0A7h, 063h, 0DFh, 038h, 0FBh, 0C5h, 039h
DB 0DDh, 014h, 04Ch, 0B0h, 0B7h, 0E2h, 044h, 082h, 0BDh, 04Bh, 0EBh, 027h, 0EDh, 0CEh, 039h, 0CCh
DB 011h, 0D7h, 008h, 014h, 0C3h, 0C7h, 066h, 038h, 0C7h, 0C3h, 00Fh, 06Dh, 058h, 0AEh, 052h, 0B9h
DB 00Fh, 0B4h, 090h, 068h, 0D7h, 0A4h, 00Fh, 038h, 059h, 05Bh, 070h, 069h, 038h, 017h, 0ABh, 04Ch
DB 0C2h, 064h, 041h, 0A2h, 066h, 002h, 019h, 0C7h, 07Fh, 013h, 021h, 037h, 081h, 088h, 06Bh, 098h
DB 0CFh, 0A2h, 072h, 0E6h, 0B3h, 08Bh, 0F0h, 099h, 0CFh, 08Eh, 012h, 0BEh, 08Fh, 0FAh, 03Ch, 051h
DB 0F2h, 0C8h, 0C0h, 077h, 077h, 09Bh, 0FBh, 0E5h, 0CDh, 079h, 042h, 0DAh, 0C6h, 022h, 0B4h, 035h
DB 098h, 0A5h, 0BFh, 08Ch, 0DDh, 099h, 0C8h, 09Ah, 068h, 09Eh, 090h, 0D2h, 04Dh, 02Dh, 0B5h, 034h
DB 03Eh, 02Ah, 0E2h, 0EBh, 0C3h, 0D5h, 0D5h, 091h, 0C9h, 0E9h, 031h, 085h, 08Bh, 02Fh, 03Fh, 03Eh
DB 07Fh, 0BEh, 0BBh, 0F9h, 076h, 048h, 0E5h, 0F0h, 089h, 062h, 03Dh, 088h, 0FAh, 051h, 040h, 017h
DB 066h, 014h, 0D1h, 0FFh, 0CBh, 036h, 0D2h, 092h, 033h, 070h, 0BEh, 0AFh, 0F9h, 07Ah, 0C9h, 031h
DB 073h, 08Dh, 0C0h, 085h, 033h, 095h, 004h, 09Eh, 033h, 065h, 080h, 0E3h, 0C9h, 038h, 089h, 0C3h
DB 024h, 0A5h, 095h, 064h, 0C5h, 00Fh, 0C2h, 02Bh, 085h, 0F3h, 0A7h, 01Ah, 03Dh, 0B9h, 0D3h, 078h
DB 025h, 038h, 0C1h, 098h, 0C0h, 045h, 050h, 04Fh, 023h, 0F2h, 0D8h, 00Eh, 0E5h, 087h, 0E9h, 034h
DB 054h, 03Dh, 0BCh, 0C5h, 044h, 0C5h, 090h, 009h, 05Fh, 00Ch, 086h, 02Bh, 08Eh, 0D8h, 021h, 0C2h
DB 0F3h, 09Ch, 06Eh, 03Dh, 055h, 000h, 03Dh, 0B4h, 040h, 02Bh, 083h, 0C4h, 002h, 04Eh, 06Ch, 0E7h
DB 0A8h, 06Ch, 0ADh, 0A6h, 075h, 0A5h, 06Ah, 0FAh, 05Bh, 0F8h, 0A7h, 033h, 047h, 067h, 085h, 02Ch
DB 06Bh, 00Ch, 097h, 033h, 030h, 001h, 073h, 0AEh, 048h, 069h, 012h, 034h, 0F8h, 088h, 077h, 06Ah
DB 02Bh, 041h, 01Bh, 0E1h, 020h, 00Ch, 06Dh, 00Bh, 0DEh, 02Ah, 069h, 0B0h, 0BCh, 01Eh, 0B4h, 093h
DB 080h, 0E3h, 07Bh, 079h, 0CCh, 0C7h, 0C3h, 024h, 092h, 0B2h, 0E8h, 08Dh, 0D0h, 0B0h, 09Ch, 0EEh
DB 084h, 06Ah, 059h, 02Bh, 0B1h, 0D8h, 0F8h, 01Ch, 0EEh, 063h, 013h, 04Ah, 043h, 02Ch, 096h, 0E3h
DB 0F1h, 0FFh, 083h, 0BCh, 052h, 0F2h, 091h, 009h, 02Ch, 0A8h, 0C2h, 0F5h, 0F9h, 0F2h, 0BAh, 0E4h
DB 061h, 0D1h, 0E2h, 00Eh, 08Fh, 097h, 007h, 08Eh, 0D5h, 0A2h, 0DDh, 00Eh, 01Ch, 07Bh, 006h, 0F5h
DB 02Bh, 0B8h, 0B1h, 016h, 004h, 014h, 01Ch, 0E0h, 065h, 051h, 045h, 02Ah, 09Bh, 05Ch, 039h, 01Eh
DB 06Dh, 09Ch, 083h, 0E4h, 0B1h, 030h, 0A0h, 03Ch, 09Fh, 0FDh, 007h

szMSZPTextLength DQ $ - szMSZPText ; (2297 Bytes >> 1035 Bytes)

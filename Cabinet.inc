; include file generated by lib2inc V2.4

CloseCompressor PROTO STDCALL :DWORD
CloseDecompressor PROTO STDCALL :DWORD
Compress PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD
CreateCompressor PROTO STDCALL :DWORD,:DWORD,:DWORD
CreateDecompressor PROTO STDCALL :DWORD,:DWORD,:DWORD
Decompress PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD
DeleteExtractedFiles PROTO STDCALL :DWORD
DllGetVersion PROTO STDCALL :DWORD
Extract PROTO STDCALL :DWORD,:DWORD
FCIAddFile PROTO C :VARARG
FCICreate PROTO C :VARARG
FCIDestroy PROTO C :VARARG
FCIFlushCabinet PROTO C :VARARG
FCIFlushFolder PROTO C :VARARG
FDICopy PROTO C :VARARG
FDICreate PROTO C :VARARG
FDIDestroy PROTO C :VARARG
FDIIsCabinet PROTO C :VARARG
FDITruncateCabinet PROTO C :VARARG
GetDllVersion PROTO STDCALL 
QueryCompressorInformation PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD
QueryDecompressorInformation PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD
ResetCompressor PROTO STDCALL :DWORD
ResetDecompressor PROTO STDCALL :DWORD
SetCompressorInformation PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD
SetDecompressorInformation PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD
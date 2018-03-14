; ////////////////////////////////////////////////////////
; ////////////////// Preprocessor Stuff //////////////////
; ////////////////////////////////////////////////////////
BITS 32

%define ExecutableBaseAddress			00010000h			; Base address of the executable
%define HacksSegmentAddress				0080b990h			; Virtual address of the .hacks segment
%define HacksSegmentOffset				005b9000h			; File offset of the .hacks segment
%define HacksSegmentSize				00002000h			; Size of the .hacks segment

; Macros
%macro HACK_FUNCTION 1
	%define %1			HacksSegmentAddress + (_%1 - _hacks_code_start)
%endmacro

%macro HACK_DATA 1
	%define %1			HacksSegmentAddress + (_%1 - _hacks_code_start)
%endmacro

; Menu handler functions
%define MenuHandler_MainMenu							001B14ECh
%define MenuHandler_GamertagSelect						002B05A4h

%define Create_MainMenu_Campaign						002B09C9h
%define Create_XboxLive_Menu							001B154Ah
%define Create_MainMenu_XboxLive						002B09A6h
%define Create_MainMenu_SplitScreen						002B0960h
%define Create_MainMenu_SystemLink						002B0983h
%define Create_MainMenu_OptionsMenu						001B1300h

; Halo Engine Functions
%define LoadScreen										000D74ECh


; void PrintDebugMessage(int category, char *psMessage, char *psTimeStamp, bool bUnk);
%define PrintDebugMessage								000AC6D0h

; Hooked Halo Engine Screen Creation Functions
%define CreateNetworkSquadBrowserScreen					001B4522h

; Kernel imports
%define imp_DbgPrint									0048084Ch

%define g_network_link									006EB2E0h
%define broadcast_search_globals_message_gateway		006E9C08h

%define c_network_message_gateway__send_message			002751A0h
%define _broadcast_search_globals_get_session_nonce		00292D30h
%define get_transport_address							00315240h

%define setsockopt										0044FD14h
%define GetLastError									0032A469h
%define malloc											0039EE0Eh
%define free											003A148Dh


; Functions in our .hacks segment.
HACK_FUNCTION Hack_PrintDebugMessage
HACK_FUNCTION Hack_MenuHandler_MainMenu

HACK_FUNCTION Hack_SendNetworkBroadcastReply_Hook
HACK_FUNCTION Hack_NetworkSquadListUpdate_Hook

HACK_DATA Hack_PrintMessageFormat
HACK_DATA Hack_FieldOfView
HACK_DATA Hack_CoffeeWatermark

HACK_DATA Hack_MenuHandler_MainMenu_JumpTable



;---------------------------------------------------------
; 
;---------------------------------------------------------		
dd			(0014F06Fh - ExecutableBaseAddress)
dd			(patch_log_leve_end - patch_log_level_start)
patch_log_level_start:

		mov		dword [59A010h], 0

patch_log_leve_end:

;---------------------------------------------------------
; Print network debug messages
;---------------------------------------------------------		
dd			(0014EB26h - ExecutableBaseAddress)
dd			(patch_print_net_dbg_end - patch_print_net_dbg_start)
patch_print_net_dbg_start:

		nop
		nop

patch_print_net_dbg_end:

;---------------------------------------------------------
; Hook debug print message function
;---------------------------------------------------------
dd			(PrintDebugMessage - ExecutableBaseAddress)
dd			(PrintDebugMessageHook_end - PrintDebugMessageHook_start)
PrintDebugMessageHook_start:

		; Jump to detour function.
		push	Hack_PrintDebugMessage
		ret

PrintDebugMessageHook_end:

;---------------------------------------------------------
; Hook MenuHandler_MainMenu
;---------------------------------------------------------		
dd			(MenuHandler_MainMenu - ExecutableBaseAddress)
dd			(MenuHandler_MainMenu_end - MenuHandler_MainMenu_start)
MenuHandler_MainMenu_start:

		; Hook to detour.
		push	Hack_MenuHandler_MainMenu
		ret

MenuHandler_MainMenu_end:

;---------------------------------------------------------
; MenuHandler_GamertagSelect -> Bypass xbl profile check shit
;---------------------------------------------------------
dd			(MenuHandler_GamertagSelect - ExecutableBaseAddress) + 70h
dd			(MenuHandler_GamertagSelect_end - MenuHandler_GamertagSelect_start)
MenuHandler_GamertagSelect_start:

		%define GamertagSelect_Base		70h
		%define GamertagSelect_Target	0C2h

		; Skip checks for xbl stuff.
		push		(MenuHandler_GamertagSelect + GamertagSelect_Target)
		ret

		%undef GamertagSelect_Target
		%undef GamertagSelect_Base

MenuHandler_GamertagSelect_end:

;---------------------------------------------------------
; Hook network squad list function that updates available sessions to jump into hacks segment
;---------------------------------------------------------
dd			(00292DDCh - ExecutableBaseAddress)
dd			(_network_squad_list_update_end - _network_squad_list_update_start)
_network_squad_list_update_start:

		; Jump into hacks segment.
		push	Hack_NetworkSquadListUpdate_Hook
		ret

_network_squad_list_update_end:

;---------------------------------------------------------
; Hook the function that sends the broadcast reply
;---------------------------------------------------------
dd			(0028736Ch - ExecutableBaseAddress)
dd			(_send_broadcast_reply_end - _send_broadcast_reply_start)
_send_broadcast_reply_start:

		; Jump into hacks segment.
		lea		eax, [esp+38h]		; game_data structure
		push	eax
		push	Hack_SendNetworkBroadcastReply_Hook
		ret

_send_broadcast_reply_end:


;---------------------------------------------------------
; .hacks code segment
;---------------------------------------------------------
dd			HacksSegmentOffset
dd			(_hacks_code_end - _hacks_code_start)
_hacks_code_start:

		;---------------------------------------------------------
		; void Hack_PrintDebugMessage(int category, char *psMessage, char *psTimeStamp, bool bUnk)
		;---------------------------------------------------------
_Hack_PrintDebugMessage:
		
		%define StackSize			0h
		%define StackStart			0h
		%define Category			4h
		%define psMessage			8h
		%define psTimeStamp			0Ch
		%define bUnknown			10h

		; Setup stack frame.
		sub		esp, StackStart

		; Print the message to debug output.
		push	dword [esp+StackSize+psMessage]			; Debug message
		push	dword [esp+StackSize+psTimeStamp+4]		; Time stamp
		push	Hack_PrintMessageFormat					; Format string
		call	dword [imp_DbgPrint]
		add		esp, 0Ch

		; Destroy stack frame and return.
		add		esp, StackStart
		ret 10h

		%undef bUnknown
		%undef psTimeStamp
		%undef psMessage
		%undef Category
		%undef StackStart
		%undef StackSize

		align 4, db 0

		;---------------------------------------------------------
		; void Hack_MenuHandler_MainMenu(void *Unk1, void *Unk2)
		;---------------------------------------------------------
_Hack_MenuHandler_MainMenu:

		%define StackSize		4h
		%define StackStart		0h
		%define Unk1			4h
		%define Unk2			8h

		; Setup stack frame.
		sub		esp, StackStart
		push	esi

		;db 0CCh

		; Get the selected menu option index and handle accordingly.
		mov		eax, [esp+StackSize+Unk2]
		movsx	eax, word [eax]
		cmp		eax, 6
		jl		_Hack_MenuHandler_MainMenu_jump
		jmp		_Hack_MenuHandler_MainMenu_done

_Hack_MenuHandler_MainMenu_jump:

		; Load jump table address using menu index.
		jmp		dword [Hack_MenuHandler_MainMenu_JumpTable+eax*4]

_Hack_MenuHandler_MainMenu_campaign:

		; Setup campaign menu.
		push	Create_MainMenu_Campaign		; Create menu function
		push	4
		push	3
		push	0
		push	dword [esp+StackSize+Unk1+10h]	; pContext
		call	Hack_LoadScreen

		jmp		_Hack_MenuHandler_MainMenu_done

_Hack_MenuHandler_MainMenu_xbox_live:

		; Setup xbox live menu.
		push	Create_MainMenu_XboxLive		; Create menu function
		push	4
		push	5
		push	0
		push	dword [esp+StackSize+Unk1+10h]	; pContext
		call	Hack_LoadScreen

		jmp		_Hack_MenuHandler_MainMenu_done

_Hack_MenuHandler_MainMenu_split_screen:

		; Setup split screen menu.
		push	Create_MainMenu_SplitScreen		; Create menu function
		push	4
		push	5
		push	0
		push	dword [esp+StackSize+Unk1+10h]	; pContext
		call	Hack_LoadScreen

		jmp		_Hack_MenuHandler_MainMenu_done

_Hack_MenuHandler_MainMenu_system_link:

		; Setup system link menu.
		push	Create_MainMenu_SystemLink		; Create menu function
		push	4
		push	5
		push	0
		push	dword [esp+StackSize+Unk1+10h]	; pContext
		call	Hack_LoadScreen

		jmp		_Hack_MenuHandler_MainMenu_done

_Hack_MenuHandler_MainMenu_options:

		; Setup options menu.
		push	Create_MainMenu_OptionsMenu		; Create menu function
		push	4
		push	5
		push	0
		push	dword [esp+StackSize+Unk1+10h]	; pContext
		call	Hack_LoadScreen

		jmp		_Hack_MenuHandler_MainMenu_done

_Hack_MenuHandler_MainMenu_saved_films:

_Hack_MenuHandler_MainMenu_done:
		; Destroy stack frame and return.
		pop		esi
		add		esp, StackStart
		ret 8

		%undef Unk2
		%undef Unk1
		%undef StackStart
		%undef StackSize

		align 4, db 0

_Hack_MenuHandler_MainMenu_JumpTable
		; Jumptable:
		dd		Hack_MenuHandler_MainMenu + (_Hack_MenuHandler_MainMenu_campaign - _Hack_MenuHandler_MainMenu)
		dd		Hack_MenuHandler_MainMenu + (_Hack_MenuHandler_MainMenu_xbox_live - _Hack_MenuHandler_MainMenu)
		dd		Hack_MenuHandler_MainMenu + (_Hack_MenuHandler_MainMenu_split_screen - _Hack_MenuHandler_MainMenu)
		dd		Hack_MenuHandler_MainMenu + (_Hack_MenuHandler_MainMenu_system_link - _Hack_MenuHandler_MainMenu)
		dd		Hack_MenuHandler_MainMenu + (_Hack_MenuHandler_MainMenu_options - _Hack_MenuHandler_MainMenu)
		dd		Hack_MenuHandler_MainMenu + (_Hack_MenuHandler_MainMenu_saved_films - _Hack_MenuHandler_MainMenu)

		;---------------------------------------------------------
		; void Hack_LoadScreen(void *pContext, DWORD Unk1, DWORD Unk2, DWORD Unk3, void *MenuCreateFunc)
		;---------------------------------------------------------
Hack_LoadScreen:

		%define StackSize		24h
		%define StackStart		1Ch
		%define MenuStruct		-1Ch
		%define SetupFunc		-4h
		%define pContext		4h
		%define Unk1			8h
		%define Unk2			0Ch
		%define Unk3			10h
		%define MenuCreateFunc	14h

		; Setup stack frame.
		sub		esp, StackStart
		push	edx
		push	edi

		; Get some value from the context pointer.
		mov		eax, [esp+StackSize+pContext]
		mov		eax, [eax]
		mov		ecx, [eax+4]

		xor		edx, edx
		inc		edx
		shl		edx, cl					; This value indicates if controller input is active on this screen or not

		; Setup the menu struct.
		lea		ecx, [esp+StackSize+MenuStruct]				; Pointer to menu struct
		push	dword [esp+StackSize+MenuCreateFunc]		; Create menu function
		push	dword [esp+StackSize+Unk3+4]				;
		push	dword [esp+StackSize+Unk2+8]				;
		xor		ax, ax										; Used by LoadScreen...
		push	edx											; Some value calculated above
		mov		edx, dword [esp+StackSize+Unk1+10h]			;
		mov		edi, LoadScreen
		call	edi

		; Call setup function?
		call	[esp+StackSize+SetupFunc]

		; Destroy stack frame and return.
		pop		edi
		pop		edx
		add		esp, StackStart
		ret 14h

		%undef MenuCreateFunc
		%undef Unk3
		%undef Unk2
		%undef Unk1
		%undef pContext
		%undef SetupFunc
		%undef MenuStruct
		%undef StackStart
		%undef StackSize

		align 4, db 0

		;---------------------------------------------------------
		; void Hack_NetworkSquadListUpdate_Hook()
		;---------------------------------------------------------
_Hack_NetworkSquadListUpdate_Hook:

		%define StackSize					4Ch
		%define StackStart					3Ch
		%define broadcast_option			-3Ch
		%define transport_addr				-38h
		%define broadcast_sockaddr			-1Ch
		%define broadcast_search_version	-0Ch
		%define broadcast_search_nonce		-8h

		; Setup stack frame.
		sub		esp, StackStart
		push	ebx
		push	ecx
		push	esi
		push	edi

		; Get the socket handle so we can set the braodcast option.
		mov		esi, dword [g_network_link]
		mov		esi, dword [esi+18h]
		mov		esi, dword [esi]

		; Setup the broadcast option.
		lea		eax, [esp+StackSize+broadcast_option]
		mov		dword [eax], 1		; broadcast_option = true

		; Put the socket into broadcasting mode.
		push	4					; sizeof(broadcast_option)
		push	eax					; &broadcast_option
		push	20h					; SO_BROADCAST
		push	0FFFFh				; SOL_SOCKET
		push	esi					; socket handle
		mov		eax, setsockopt
		call	eax
		cmp		eax, 0
		jz		_Hack_NetworkSquadListUpdate_Hook_continue

		; Get the last error code.
		mov		eax, GetLastError
		call	eax
		db 0CCh

_Hack_NetworkSquadListUpdate_Hook_continue:
		; Setup the broadcast search data.
		mov		word [esp+StackSize+broadcast_search_version], 2		; broadcast_search.protocol_version = 0
		mov		word [esp+StackSize+broadcast_search_version+2], 0		; broadcast_search.reserved = 0

		; Get the broadcast session nonce.
		lea		esi, [esp+StackSize+broadcast_search_nonce]
		mov		eax, _broadcast_search_globals_get_session_nonce
		call	eax

		; Setup the broadcast sockaddr structure.
		lea		esi, [esp+StackSize+broadcast_sockaddr]		; &broadcast_sockaddr
		mov		word [esi], 2								; broadcast_sockaddr.sin_family = AF_INET
		mov		word [esi+2], 03E9h							; broadcast_sockaddr.sin_port = 1001
		mov		dword [esi+4], 0FFFFFFFFh					; broadcast_sockaddr.sin_addr = INADDR_BROADCAST
		mov		dword [esi+8], 0
		mov		dword [esi+0Ch], 0

		; Zero out the transport address struct.
		cld
		lea		edi, [esp+StackSize+transport_addr]
		mov		eax, 0
		mov		ecx, 7
		rep stosd				; memset(&transport_addr, 0, sizeof(transport_addr));

		; Convert the broadcast sockaddr to a transport address structure.
		lea		eax, [esp+StackSize+broadcast_sockaddr]		; &broadcast_sockaddr
		lea		esi, [esp+StackSize+transport_addr]			; &transport_addr
		push	16											; sizeof(sockaddr_in)
		mov		ecx, get_transport_address
		call	ecx

		; Get the context pointer thingo so we can send the network message.
		mov		ebx, dword [broadcast_search_globals_message_gateway]

		; Send the broadcast message.
		lea		eax, [esp+StackSize+broadcast_search_version]
		push	eax											; &broadcast_search_version
		push	12											; sizeof(s_network_message_broadcast_search)
		push	2											; _network_message_type_broadcast_search
		lea		eax, [esp+StackSize+transport_addr+0Ch]
		push	eax											; &transport_addr
		push	ebx
		mov		eax, c_network_message_gateway__send_message
		call	eax

_Hack_NetworkSquadListUpdate_Hook_done:
		; Destroy stack frame.
		pop		edi
		pop		esi
		pop		ecx
		pop		ebx
		add		esp, StackStart

		; Instructions we replaced in the hook.
		mov		al, [006EB3FCh]		; Check which tick count to use
		test	al, al
		jz		_Hack_NetworkSquadListUpdate_Hook_use_tick_count

		; Jump to trampoline.
		push	00292DE5h
		ret

_Hack_NetworkSquadListUpdate_Hook_use_tick_count:

		; Jump to trampoline.
		push	00292DECh
		ret

		%undef broadcast_search_nonce
		%undef broadcast_search_version
		%undef broadcast_sockaddr
		%undef transport_addr
		%undef StackStart
		%undef StartSize

		align 4, db 0

		;---------------------------------------------------------
		; void Hack_SendNetworkBroadcastReply_Hook(void *game_data)
		;---------------------------------------------------------
_Hack_SendNetworkBroadcastReply_Hook:

		%define StackSize				44h
		%define StackStart				34h
		%define broadcast_search		-34h
		%define broadcast_option		-30h
		%define broadcast_sockaddr		-2Ch
		%define transport_addr			-1Ch
		%define game_data				0h		; no return address so first arg is at +0

		; Setup the stack frame.
		sub		esp, StackStart
		push	ebx
		push	ecx
		push	esi
		push	edi

		; Save the broadcast search message pointer.
		mov		dword [esp+StackSize+broadcast_search], edi

		; Get the socket handle so we can set the braodcast option.
		mov		esi, dword [g_network_link]
		mov		esi, dword [esi+18h]
		mov		esi, dword [esi]

		; Setup the broadcast option.
		lea		eax, [esp+StackSize+broadcast_option]
		mov		dword [eax], 1		; broadcast_option = true

		; Put the socket into broadcasting mode.
		push	4					; sizeof(broadcast_option)
		push	eax					; &broadcast_option
		push	20h					; SO_BROADCAST
		push	0FFFFh				; SOL_SOCKET
		push	esi					; socket handle
		mov		eax, setsockopt
		call	eax
		cmp		eax, 0
		jz		Hack_SendNetworkBroadcastReply_Hook_continue

		; Get the last error code.
		mov		eax, GetLastError
		call	eax
		db 0CCh

Hack_SendNetworkBroadcastReply_Hook_continue:

		; Setup the broadcast sockaddr structure.
		lea		esi, [esp+StackSize+broadcast_sockaddr]		; &broadcast_sockaddr
		mov		word [esi], 2								; broadcast_sockaddr.sin_family = AF_INET
		mov		word [esi+2], 03E9h							; broadcast_sockaddr.sin_port = 1001
		mov		dword [esi+4], 0FFFFFFFFh					; broadcast_sockaddr.sin_addr = INADDR_BROADCAST
		mov		dword [esi+8], 0
		mov		dword [esi+0Ch], 0

		; Zero out the transport address struct.
		cld
		lea		edi, [esp+StackSize+transport_addr]
		mov		eax, 0
		mov		ecx, 7
		rep stosd				; memset(&transport_addr, 0, sizeof(transport_addr));

		; Convert the broadcast sockaddr to a transport address structure.
		lea		eax, [esp+StackSize+broadcast_sockaddr]		; &broadcast_sockaddr
		lea		esi, [esp+StackSize+transport_addr]			; &transport_addr
		push	16											; sizeof(sockaddr_in)
		mov		ecx, get_transport_address
		call	ecx

		; Allocate some memory for the reply data.
		push	1800			; sizeof(s_network_message_broadcast_reply)
		mov		eax, malloc
		call	eax
		add		esp, 4			; Cleanup from malloc()
		cmp		eax, 0
		jz		Hack_SendNetworkBroadcastReply_Hook_done
		mov		ecx, eax

		;db 0CCh

		; Setup the reply header using the nonce from the search message.
		mov		ebx, dword [esp+StackSize+broadcast_search]
		mov		word [ecx], 2			; broadcast_reply_data.protocol = 0
		mov		word [ecx+2], 0
		mov		eax, dword [ebx+4]		; broadcast_search.nonce
		mov		dword [ecx+4], eax		; broadcast_reply_data.nonce = broadcast_search.nonce
		mov		eax, dword [ebx+8]		; broadcast_search.nonce
		mov		dword [ecx+8], eax		; broadcast_reply_data.nonce = broadcast_search.nonce

		; Copy the game data into the rest of the message.
		mov		esi, dword [esp+StackSize+game_data]		; src = game_data
		lea		edi, [ecx+0Ch]								; dst = broadcast_reply_data + sizeof(s_network_message_broadcast_search)
		push	ecx
		mov		ecx, 1788									; size = sizeof(s_network_message_broadcast_reply) - sizeof(s_network_message_broadcast_search)
		rep movsb
		pop		ecx

		; Save the address of the allocation for later.
		mov		dword [esp+StackSize+broadcast_search], ecx

		; Get the context pointer thingo so we can send the network message.
		mov		ebx, dword [broadcast_search_globals_message_gateway]

		; Send the broadcast message.
		push	ecx											; &broadcast_reply_data
		push	1800										; sizeof(s_network_message_broadcast_reply)
		push	3											; _network_message_type_broadcast_reply
		lea		eax, [esp+StackSize+transport_addr+0Ch]
		push	eax											; &transport_addr
		push	ebx
		mov		eax, c_network_message_gateway__send_message
		call	eax

		; Free the allocation we made for the reply data.
		mov		eax, [esp+StackSize+broadcast_search]
		push	eax
		mov		eax, free
		call	eax
		add		esp, 4

Hack_SendNetworkBroadcastReply_Hook_done:
		; Destroy the stack frame and return.
		pop		edi
		pop		esi
		pop		ecx
		pop		ebx
		add		esp, StackStart

		; Jump back into function.
		push	002873C8h
		ret 4

		%undef game_data
		%undef transport_addr
		%undef broadcast_sockaddr
		%undef broadcast_option
		%undef broadcast_search
		%undef StackStart
		%undef StackSize

		align 4, db 0

_Hack_PrintMessageFormat:
		db '[%s] %s',0
		align 4, db 0

_hacks_code_end:

; ////////////////////////////////////////////////////////
; //////////////////// End of file ///////////////////////
; ////////////////////////////////////////////////////////
dd -1
end
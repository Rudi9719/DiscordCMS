/* REXX */
/* --------------------------------------------------------------------------*/
/* DISCORD EXEC - CMS Client for Discord Service                             */
/* --------------------------------------------------------------------------*/
Parse upper arg mode '('opts
Trace Off
Address Command
Numeric Digits 20
/* Bail early if GOPWIN is not detected */
'NUCEXT GOPWIN'
If rc <> 0 Then Do
   'ESTATE GOPWIN MODULE *'
   If rc <> 0 Then Call ErrorExit 'GOPWIN MODULE not found.'
End
/* If we have GOPWIN, get saved variables */
GW_ID = ''
'GLOBALV GET DISCORD_LAST'
'CP SET IMSG OFF'
'CP SET MSG OFF'
 
/* Did user request a clear? */
If opts = 'CLEAR' Then do
DISCORD_LAST = ''
End
If mode = 'LIST' Then DISCORD_LAST=''
If DATATYPE(mode,'W') Then DISCORD_LAST=mode
 
/* Are saved variables garbage? */
If ¬DATATYPE(DISCORD_LAST,'W') Then DISCORD_LAST=''
 
/* Shared GOPWIN Control pattern stem */
CTL.0 = 5
CTL.1 = '¦ FIELD PROT BLUE'
CTL.2 = '¬ FIELD PROT GREEN'
CTL.3 = '^ FIELD PROT WHITE'
CTL.4 = '± FIELD PROT YELLOW'
CTL.5 = '¢ FIELD NOPROT WHITE UND VARIABLE uinput'
 
 
ADDRESS COMMAND 'GOPWIN INIT GW_ID (FORCE'
ADDRESS COMMAND 'GOPWIN QUERY GW_ID (STEM GW_ID.'
ADDRESS COMMAND 'GOPWIN TERM GW_ID'
Parse var GW_ID.SIZE rows cols
DISCORD_HT = rows
If ¬DATATYPE(DISCORD_HT,'W') Then DISCORD_HT=10
 
/* If opts are a Whole number they're the height */
if DATATYPE(opts, 'W') Then DISCORD_HT = opts
 
 
/* Split main loop into Proc for clenliness */
Call MainProc
 
Say 'Goodbye!'
ADDRESS COMMAND 'GOPWIN TERM GW_ID'
'CP SET IMSG ON'
'CP SET MSG ON'
 
Exit 0
 
MainProc: procedure expose GW_ID. CTL. DISCORD_HT DISCORD_LAST
If ¬DATATYPE(DISCORD_LAST,'W') Then DISCORD_LAST=ListChans()
msg = ''
Do while msg<>'QUIT'
   msg = ReadHistory()
   Parse upper var msg msgUpper .
   select
      When STRIP(msg) = '' Then Iterate
      When msgUpper = 'QUIT' Then Leave
      When msgUpper = 'Q' Then Leave
      When msgUpper = 'LIST' Then DISCORD_LAST = ListChans()
      When msgUpper = 'LI' Then DISCORD_LAST = ListChans()
      otherwise do
         'EXEC TELL DISCORD S 'DISCORD_LAST' 'msg
      End
   End
End
Return
 
/* --------------------------------------------------------------------*/
/* SUBROUTINE: ReadHistory                                             */
/* Tell DISCORD to give us the history for a particular channel.       */
/* --------------------------------------------------------------------*/
ReadHistory: procedure expose CTL. GW_ID. DISCORD_HT DISCORD_LAST
If DISCORD_LAST = '' Then Call ErrorExit 'No channel specified to ReadHistory.'
'EXEC TELL DISCORD HIST 'DISCORD_LAST' 99'
uinput=''
 
histFile = WaitForFile('DISCORD HIST')
 
'EXEC RECEIVE 'histFile' (REPLACE'
'EXECIO * DISKR DISCORD HIST A (STEM DHIST. FINIS'
If rc<>0 Then Call ErrorExit 'Failed to read DISCORD HIST A'
'ERASE DISCORD HIST A'
'GLOBALV PUT DISCORD_LAST'

Parse var DHIST.1 ChanID '|' ChanName '|' MsgReq '|' PreparedTs
HEAD_PAT.1 = '¦ 'ChanName' history as of ¬'PreparedTs' ¦[c'MsgReq'/h'DISCORD_HT']'
HEAD_PAT.2 = '¦-------------------------------------------------------------------------------'
HEAD_PAT.0 = 2

FOOT_PAT.1 = '¦-- Input (LIst, Quit, a message, or blank to refresh)¬PF7/8 Scroll,PF3 QUIT¦---'
FOOT_PAT.2 = ' ¢                                                                              '
FOOT_PAT.0 = 2

Idx = 1
Do i=2 to DHIST.0 - 1
     If POS('M|', DHIST.i) = 1 Then Do
         Parse var DHIST.i 'M|' MsgTs '|' MsgAuthor '|' Msg
         BODY_PAT.Idx = ' ¬'MsgTs'^'MsgAuthor':±'STRIP(Msg, 'L')
     End
     Else Do
         BODY_PAT.Idx = '± 'DHIST.i
     End
     Idx = Idx + 1
End
BODY_PAT.0 = Idx - 1
BodyHeight = DISCORD_HT - 4 
If BodyHeight < 1 Then BodyHeight = 1
ScrollRow = BODY_PAT.0 - BodyHeight + 1
If ScrollRow < 1 Then ScrollRow = 1
BodyStartRow = 3
FootStartRow = DISCORD_HT - 1

ADDRESS COMMAND 'GOPWIN INIT GW_ID (FORCE'
ADDRESS COMMAND 'GOPWIN DEFINE GW_ID HEAD_WIN HEAD_PAT. CTL. (NOBORD LOC ABS 1 0'
ADDRESS COMMAND 'GOPWIN DEFINE GW_ID BODY_WIN BODY_PAT. CTL. (NOBORD LOC ABS 'BodyStartRow' 0 ASIZE 'BodyHeight' *'
ADDRESS COMMAND 'GOPWIN DEFINE GW_ID FOOT_WIN FOOT_PAT. CTL. (NOBORD LOC ABS 'FootStartRow' 0 CUR uinput'

ExitLoop = 0
ADDRESS COMMAND 'GOPWIN CHANGE GW_ID BODY_WIN (AORIGIN 'ScrollRow' 1'

Do Until ExitLoop = 1
ADDRESS COMMAND 'GOPWIN DISPLAY GW_ID HEAD_WIN BODY_WIN FOOT_WIN (FORCE CUR FOOT_WIN'
    
    Select
        When GOPWIN.PFK = 'PF7' Then Do
            ScrollRow = ScrollRow - (BodyHeight - 1)
            If ScrollRow < 1 Then ScrollRow = 1
         ADDRESS COMMAND 'GOPWIN CHANGE GW_ID BODY_WIN (AORIGIN 'ScrollRow' 1'
        End
        When GOPWIN.PFK = 'PF8' Then Do
            MaxRow = BODY_PAT.0 - BodyHeight + 1
            If MaxRow < 1 Then MaxRow = 1
            
            ScrollRow = ScrollRow + (BodyHeight - 1)
            If ScrollRow > MaxRow Then ScrollRow = MaxRow
         ADDRESS COMMAND 'GOPWIN CHANGE GW_ID BODY_WIN (AORIGIN 'ScrollRow' 1'
        End
        When GOPWIN.PFK = 'PF3' | GOPWIN.PFK = 'PF15' Then Do
            Call ErrorExit 'Goodbye!'
        End
        When GOPWIN.PFK = 'ENTER' Then Return uinput
        
        Otherwise NOP
    End
End
Return uinput
 
/* --------------------------------------------------------------------------*/
/* Subroutine: WaitForFile                                                   */
/* Waits for Target then returns SpoolID to be used                          */
/* --------------------------------------------------------------------------*/
WaitForFile: Procedure
   Parse Arg TargetFn TargetFt
   Found = 0
   SpoolID = ''
   Do 5
      'DESBUF'
      'EXECIO * CP (STEM RDR. STRING QUERY RDR * ALL'
      Do r = 1 to RDR.0
         Line = RDR.r
         If POS(TargetFn, Line) > 0 & POS(TargetFt, Line) > 0 Then Do
            Parse var Line 'RSCS     'SpoolID' A PUN'
            Found = 1
         End
      End
 
      If Found Then Leave
      'CP SLEEP 2 SEC'
   End
 
   If ¬Found Then Call ErrorExit 'Timeout waiting for' TargetFn TargetFt
Return SpoolID
 
/* --------------------------------------------------------------------------*/
/* SUBROUTINE: ErrorExit                                                     */
/* Something went horribly wrong!                                            */
/* --------------------------------------------------------------------------*/
ErrorExit: Procedure
   Parse Arg Msg
   ADDRESS COMMAND 'GOPWIN TERM GW_ID'
   Say 'ERROR:' Msg
   'CP SET MSG ON'
   'CP SET IMSG ON'
   Exit 100
Return
 
/* --------------------------------------------------------------------------*/
/* SUBROUTINE: ListChans                                                     */
/* Tell DISCORD to give us the channel list.                                 */
/* --------------------------------------------------------------------------*/
ListChans: procedure expose CTL. GW_ID. DISCORD_HT
'EXECIO * DISKR DISCORD LIST A (STEM DLIST. FINIS'
If rc<>0 Then do
Say 'Preparing DISCORD LIST please wait for network. . .'
'EXEC TELL DISCORD LIST'
listFile = WaitForFile('DISCORD LIST')
'EXEC RECEIVE 'listFile' (REPLACE'
'EXECIO * DISKR DISCORD LIST A (STEM DLIST. FINIS'
If rc<>0 Then Call ErrorExit 'Failed to read DISCORD LIST A'
end
uinput=''
 
Parse var DLIST.1 Type '|' ChanCount '|' ListTime

HEAD_PAT.1=' ¦DISCORD CHANNELS (¬ 'STRIP(ChanCount)' ¦)'
HEAD_PAT.2=' ¦Updated: ¬' || ListTime
HEAD_PAT.3=' ¦Channel:¢                                                        '
HEAD_PAT.4=' ¦-----±PF7/8 to scroll up/down, PF3 to QUIT¦-------------------------------'
HEAD_PAT.0 = 4

Idx = 1
ChanList.0 = ''
Do i=2 to DLIST.0 - 1
    ChanTopic = ''
    If POS('L|', DLIST.i) = 1 Then Do
        Parse var DLIST.i 'L|'ChanName'|'ChanID'|'ChanTopic
        LIST_PAT.Idx = '^'ChanName':'
        Idx = Idx + 1
    End
    Else do
        ChanTopic = DLIST.i
    End
    LIST_PAT.Idx = ' ¬'ChanTopic
    Idx = Idx + 1
End
LIST_PAT.0 = Idx - 1
ListHeight = DISCORD_HT - HEAD_PAT.0
If LIST_PAT.0 < ListHeight Then ListHeight = LIST_PAT.0

ScrollRow = 1
ExitLoop = 0
 
ADDRESS COMMAND 'GOPWIN INIT GW_ID (FORCE'
ADDRESS COMMAND 'GOPWIN DEFINE GW_ID HEAD_WIN HEAD_PAT. CTL. (NOBORD LOC ABS 1 0 CUR uinput'
ADDRESS COMMAND 'GOPWIN DEFINE GW_ID LIST_WIN LIST_PAT. CTL. (NOBORD LOC ABS 5 0 ASIZE 'ListHeight' *'

Do Until ExitLoop = 1
    ADDRESS COMMAND 'GOPWIN DISPLAY GW_ID HEAD_WIN LIST_WIN (FORCE CUR HEAD_WIN'
    
    Select
        When GOPWIN.PFK = 'PF7' Then Do
            ScrollRow = ScrollRow - (ListHeight - 1)
            If ScrollRow < 1 Then ScrollRow = 1
         ADDRESS COMMAND 'GOPWIN CHANGE GW_ID LIST_WIN (AORIGIN 'ScrollRow' 1'
        End

        When GOPWIN.PFK = 'PF8' Then Do
            MaxRow = LIST_PAT.0 - ListHeight + 1
            If MaxRow < 1 Then MaxRow = 1
            
            ScrollRow = ScrollRow + (ListHeight - 1)
            If ScrollRow > MaxRow Then ScrollRow = MaxRow
            
         ADDRESS COMMAND 'GOPWIN CHANGE GW_ID LIST_WIN (AORIGIN 'ScrollRow' 1'
        End
        When GOPWIN.PFK = 'PF3' | GOPWIN.PFK = 'PF15' Then Do
            uinput = '' 
            Call ErrorExit 'Goodbye!'
        End
        When GOPWIN.PFK = 'ENTER' Then ExitLoop = 1
        
        Otherwise NOP
    End
end

target = ''
Found = 0

If uinput <>'' Then Do
   Parse upper var uinput check
   If STRIP(check) = 'QUIT' then call ErrorExit 'Goodbye!'
    Do i=2 to DLIST.0 - 1
        Parse upper var DLIST.i 'L|'ChanName'|'ChanID'|'ChanTopic
        If check = ChanName Then Do
          target = ChanID
          Found = 1
          Leave
        End
    End
    If ¬Found Then Call ErrorExit 'Channel not found in list.'
End
Else Do
    target = '' 
End
Return target
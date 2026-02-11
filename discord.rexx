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
'GLOBALV GET DISCORD_LAST DISCORD_HT'
'CP SET IMSG OFF'
'CP SET MSG OFF'
 
/* Did user request a clear? */
If opts = 'CLEAR' Then do
Say 'Opts: 'opts
DISCORD_LAST = ''
DISCORD_HT = ''
End
 
/* Are saved variables garbage? */
If ¬DATATYPE(DISCORD_HT,'W') Then DISCORD_HT=24
If ¬DATATYPE(DISCORD_LAST,'W') Then DISCORD_LAST=''
 
/* Shared GOPWIN Control pattern stem */
CTL.0 = 5
CTL.1 = '¦ FIELD PROT BLUE'
CTL.2 = '¬ FIELD PROT GREEN'
CTL.3 = '^ FIELD PROT WHITE'
CTL.4 = '± FIELD PROT YELLOW'
CTL.5 = '¢ FIELD NOPROT WHITE UND VARIABLE uinput'
 
/* If opts are a Whole number they're the height */
if DATATYPE(opts, 'W') Then do
    DISCORD_HT = opts
    'GLOBALV PUT DISCORD_HT'
    end
else do
end
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
      When msgUpper = 'LIST' Then do
         DISCORD_LAST = ListChans()
      End
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
'EXEC TELL DISCORD HIST 'DISCORD_LAST' 'DISCORD_HT
uinput=''
 
histFile = WaitForFile('DISCORD HIST')
 
'EXEC RECEIVE 'histFile' (REPLACE'
'EXECIO * DISKR DISCORD HIST A (STEM DHIST. FINIS'
If rc<>0 Then Call ErrorExit 'Failed to read DISCORD HIST A'
'ERASE DISCORD HIST A'
'GLOBALV PUT DISCORD_LAST'
 
Parse var DHIST.1 ChanID '|' ChanName '|' MsgReq '|' PreparedTs
Idx = 3
StartIdx = DHIST.0 - (DISCORD_HT - 4)
MsgCt = 0
HIST_PAT.2 = '¦-----------------------------------------------------------------
-------------'
 
Do i=StartIdx to DHIST.0
 
     If POS('M|', DHIST.i) = 1 Then Do
         Parse var DHIST.i 'M|' MsgTs '|' MsgAuthor '|' Msg
         HIST_PAT.Idx = ' ¬'MsgTs'^'MsgAuthor':±'STRIP(Msg, 'L')
         MsgCt = MsgCt + 1
     End
     Else Do
         HIST_PAT.Idx = '± -'DHIST.i
     End
 
     Idx = Idx + 1
End
 
HIST_PAT.1 = '¦ 'ChanName' History as of ¬'PreparedTs' ¦['MsgCt'/'MsgReq']'
 
foot = DISCORD_HT - 1
HIST_PAT.foot = '¦ User input (List, Quit, a Message, or blank to refresh)'
HIST_PAT.DISCORD_HT = ' ¢
   '
 
 
HIST_PAT.0 = DISCORD_HT
ADDRESS COMMAND 'GOPWIN INIT GW_ID (FORCE'
ADDRESS COMMAND 'GOPWIN DEFINE GW_ID MAIN_WIN HIST_PAT. CTL. (NOBORD LOC ABS 1 0
 CUR uinput'
ADDRESS COMMAND 'GOPWIN DISPLAY GW_ID MAIN_WIN (FORCE'
 
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
ListChans: procedure expose CTL. GW_ID.
Say 'Preparing DISCORD LIST please wait for network. . .'
'EXEC TELL DISCORD LI'
listFile = WaitForFile('DISCORD LI')
uinput=''
'EXEC RECEIVE 'listFile' (REPLACE'
'EXECIO * DISKR DISCORD LI A (STEM DLIST. FINIS'
If rc<>0 Then Call ErrorExit 'Failed to read DISCORD LI A'
'ERASE DISCORD LI A'
 
Parse var DLIST.1 Type '|' ChanCount '|' ListTime
LIST_PAT.1='¦DISCORD CHANNELS (¬ 'STRIP(ChanCount)' ¦)'
LIST_PAT.2='¦Updated: ¬' || ListTime
LIST_PAT.3='¦-------------------------------------------------------------------
------------'
Idx = 4
CIdx = 1
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
 
LIST_PAT.Idx = '¦Channel:¢                                                     '
 
LIST_PAT.0 = Idx
 
ADDRESS COMMAND 'GOPWIN INIT GW_ID (FORCE'
ADDRESS COMMAND 'GOPWIN DEFINE GW_ID MAIN_WIN LIST_PAT. CTL. (NOBORD LOC ABS 1 0
 CUR uinput'
ADDRESS COMMAND 'GOPWIN DISPLAY GW_ID MAIN_WIN (FORCE'
 
target = ''
Found = 0
Do i=2 to DLIST.0 - 1
    Parse var DLIST.i 'L|'ChanName'|'ChanID'|'ChanTopic
    If uinput = ChanName Then Do
      target = ChanID
      Found = 1
      Leave
    End
End
 
If ¬Found Then Call ErrorExit 'Channel not found in list.'
Return target

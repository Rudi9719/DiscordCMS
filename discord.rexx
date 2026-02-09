/* REXX */
/* ------------------------------------------------------------------ */
/* DISCORD EXEC - CMS Client for Discord Service                      */
/* ------------------------------------------------------------------ */
Parse arg mode '('iheight
Trace Off
Address Command
Numeric Digits 20        


'NUCEXT GOPWIN'
If rc <> 0 Then Do
   'ESTATE GOPWIN MODULE *'
   If rc <> 0 Then Call ErrorExit 'GOPWIN MODULE not found.'
End

Say 'Preparing DISCORD LIST please wait. . .'

GW_ID = ''
uinput = ''
height=24

CTL.0 = 6
CTL.1 = '| FIELD PROT BLUE'
CTL.2 = '¬ FIELD PROT GREEN'
CTL.3 = '^ FIELD PROT WHITE'
CTL.4 = '\ FIELD NOPROT WHITE UND'
CTL.5 = '@ FIELD PROT YELLOW'
CTL.6 = '¢ FIELD NOPROT WHITE UND VARIABLE uinput'

'EXEC TELL DISCORD LI'
listFile = WaitForFile('DISCORD LI')

'EXEC RECEIVE 'listFile' (REPLACE'

'EXECIO * DISKR DISCORD LI A (STEM DLIST. FINIS'
If rc<>0 Then Call ErrorExit 'Failed to read DISCORD LI A'
'ERASE DISCORD LI A'

Parse var DLIST.1 Type '|' ChanCount '|' ListTime
LIST_PAT.1='|DISCORD CHANNELS (¬' || STRIP(ChanCount) || '|)'
LIST_PAT.2='|Updated: ¬' || ListTime
LIST_PAT.3='|-----------------------------------------------------------------------------'
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
LIST_PAT.Idx = '|Channel:¢                                              ^'
LIST_PAT.0 = Idx


ADDRESS COMMAND 'GOPWIN INIT GW_ID'
ADDRESS COMMAND 'GOPWIN DEFINE GW_ID MAIN_WIN LIST_PAT. CTL. (NOBORD LOC ABS 1 0 CUR uinput'
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
If ¬Found Then Call ErrorExit 'Channel not found.'
if iheight<>'' Then Do 
    height = iheight
End
'EXEC TELL DISCORD HIST 'target' 'height
histFile = WaitForFile('DISCORD HIST')


ADDRESS COMMAND 'GOPWIN TERM GW_ID' 
'EXEC PEEK 'histFile
Exit 0

/* ------------------------------------------------------------------ */
/* Subroutine: WaitForFile                                            */
/* Waits for Target then returns SpoolID to be used                   */
/* ------------------------------------------------------------------ */
WaitForFile: Procedure
   Parse Arg TargetFn TargetFt
   Found = 0
   SpoolID = ''
   Do 12
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
      'CP SLEEP 1 SEC'
   End
   
   If ¬Found Then Call ErrorExit 'Timeout waiting for' TargetFn TargetFt 
Return SpoolID

/* ------------------------------------------------------------------ */
/* SUBROUTINE: ErrorExit                                              */
/* Something went horribly wrong!                                     */
/* ------------------------------------------------------------------ */
ErrorExit: Procedure
   Parse Arg Msg
   ADDRESS COMMAND 'GOPWIN TERM GW_ID' 
   Say 'ERROR:' Msg
   Exit 100
Return
$ VER_IFY='F$VERIFY(0)                         ! Get verification.
$ SET NOON
$ ON CONTROL_Y THEN GOTO END
$!
$ !
$ BA*SIC :== BASIC/REAL=DOUBLE/FLAGS=NODECLINING
$ ASSIGN :== ASSIGN/NOLOG
$ DEFINE :== DEFINE/NOLOG
$ !
$ ADD           == "$ DMS:ADD"
$ ASQ           == "$ DMS:ASQ"
$ BLA*NK        == "$ DMS:BLANK"
$ CAL*CULATE    == "$ DMS:CALCULATE"
$ CMP*ARE       == "$ DMS:COMPARE"
$ PDE*LETE      == "$ DMS:DELETE"
$ DES*CRIBE     == "$ DMS:DESCRIBE"
$ EXP*UNGE      == "$ DMS:EXPUNGE"
$ EXT*END       == "$ DMS:EXTEND"
$ FOR*M         == "$ DMS:FORM"
$ HEA*DER       == "$ DMS:HEADER"
$ KEY           == "$ DMS:KEY"
$ LAB*EL        == "$ DMS:LABEL"
$ POI*NTER      == "$ DMS:POINTER"
$ PPR*INT       == "$ DMS:PRINT"
$ PPU*RGE       == "$ DMS:PURGE"
$ QUE*BATCH     == "$ DMS:QUEBATCH"
$ SAV*E         == "$ DMS:SAVE"
$ SCO*PE        == "$ DMS:SCOPE"
$ SCR*EEN       == "$ DMS:SCREEN"
$ SEA*RCH       == "$ DMS:SEARCH"
$ SOR*T         == "$ DMS:SORT"
$ TRA*NSFER     == "$ DMS:TRANSFER"
$ UPD*ATE       == "$ DMS:UPDATE"
$ XTA*B         == "$ DMS:XTAB"
$ !
$ ! Assign Logicals
$ !
$ DEFINE SCHOOL_NAME            "University of Science & Arts"
$ @dka100:[reg.exe]REGLOGS
$ !
$ ! @ADMSYS_EXE:[ADM60.EXE]ADMLOGS -
        ADMSYS_FILES:[ADM60.FILES] -
        ADMSYS_EXE:[ADM60.EXE] -
        ADMSYS_FILES:[ADM60.FILES] -
        REGSYS_FILES:[REG.DBCENTREL.FILES] -
        REGSYS_EXE:[REG.DBCENTREL.EXE]
$ !
$ ! assign dka100:[usaofa]sapfile sapfile
$ PPR*INT       == "$ DMS:PRINT"
$ PPU*RGE       == "$ DMS:PURGE"
$ QUE*BATCH     == "$ DMS:QUEBATCH"
$ SAV*E         == "$ DMS:SAVE"
$ SCO*PE        == "$ DMS:SCOPE"
$ SCR*EEN       == "$ DMS:SCREEN"
$ SEA*RCH       == "$ DMS:SEARCH"
$ SOR*T         == "$ DMS:SORT"
$ TRA*NSFER     == "$ DMS:TRANSFER"
$ UPD*ATE       == "$ DMS:UPDATE"
$ XTA*B         == "$ DMS:XTAB"
$ !
$ ! Assign Logicals
$ !
DEFINE SCHOOL_NAME            "University of Science & Arts"
@dka100:[reg.exe]REGLOGS
!
! @ADMSYS_EXE:[ADM60.EXE]ADMLOGS -
        ADMSYS_FILES:[ADM60.FILES] -
        ADMSYS_EXE:[ADM60.EXE] -
        ADMSYS_FILES:[ADM60.FILES] -
        REGSYS_FILES:[REG.DBCENTREL.FILES] -
        REGSYS_EXE:[REG.DBCENTREL.EXE]
!
! assign dka100:[usaofa]sapfile sapfile
! define reg$def_termcode     131S
! SET TERM/DEV=VT102/FORM
! DEFINE DMS$DEF_BATCH                AID$BATCH
! DEFINE DMS$DEF_PAPER                DEFAULT
! DEFINE DMS$DEF_PRINT                FA_LASER:
DELETE        == "DELETE/LOG"
PRINT         == "PRINT/NOTIFY"
SUBMIT        == "SUBMIT/NOTIFY"
RENAME        == "RENAME/LOG"
COPY          == "COPY/LOG"
!
! Added new hold code 11-8-13 (LB)
HOLDS$= "LIB"
DEFINE/NOLOG REG$HOLDCODELIST "''HOLDS$'"
DEFINE/NOLOG REG$OFFICE "LIB"
!
@dms:dmsmenu menu
ON CONTROL_Y THEN EXIT                       ! Remove ^Y trap.
IF VER_IFY THEN SET VERIFY                   ! Restore original verification
if F$MODE() .eqs. "INTERACTIVE" then logout

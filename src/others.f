
C *** PURPOSE 
C ***  TO CALCULATE THE WATER AND SOLUTE MASS IN EACH NODE  
C ***  WMA INCLUDES ALL THE SOLUTE IN LIQUID AND SOLID FORM
C ***  SM  IS SOLUTE IN SOLID FORM
C ***  SEE NOTEBOOK3 
      SUBROUTINE WSMASS(WMA,SMA,VOL,POR,SW,RHO,SOP,DSWDP,PVEC,
     1   PM1,UM1,UM2,CS1,CS2,CS3,SL,SR,DPDTITR,UVEC,ITER,SM,QPLITR,
     2   QIN,QINITR,UIN,IPBC,GNUP1,PBC,UBC,ISTOP,QSB,USB,QPB,UPB,NWS,
     3   WMAM,IQSOP,CJGNUP,WMA1,SMA1)
      USE M_PARAMS
      USE M_ET
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
      COMMON /TIMES/ DELT,TSEC,TMIN,THOUR,TDAY,TWEEK,TMONTH,TYEAR,     
     1   TMAX,DELTP,DELTU,DLTPM1,DLTUM1,IT,ITBCS,ITRST,ITMAX,TSTART     
      COMMON /DIMS/ NN,NE,NIN,NBI,NCBI,NB,NBHALF,NPBC,NUBC,
     1   NSOP,NSOU,NBCN,NCIDB
      COMMON /CONTRL/ GNUP,GNUU,UP,DTMULT,DTMAX,ME,ISSFLO,ISSTRA,ITCYC, 
     1   NPCYC,NUCYC,NPRINT,NBCFPR,NBCSPR,NBCPPR,NBCUPR,IREAD,          
     2   ISTORE,NOUMAT,IUNSAT,KTYPE,MET,MAR,MSR,MSC,MHT,MVT,MFT,MRK
      COMMON /DIMX2/ NELTA, NNVEC, NDIMIA, NDIMJA
      COMMON /PARAMS/ COMPFL,COMPMA,DRWDU,CW,CS,RHOS,SIGMAW,SIGMAS,
     1   RHOW0,URHOW0,VISC0,PRODF1,PRODS1,PRODF0,PRODS0,CHI1,CHI2 
      DIMENSION KTYPE(2)
      DIMENSION WMA(NN),SMA(NN),VOL(NN),POR(NN),SW(NN),RHO(NN),UM1(NN),
     1   SOP(NN),DSWDP(NN),PM1(NN),UM2(NN),CS1(NN),
     1   CS2(NN),CS3(NN),SL(NN),SR(NN),DPDTITR(NN)
      DIMENSION PVEC(NNVEC),UVEC(NNVEC),SM(NN),QPLITR(NBCN)
      DIMENSION QIN(NN),QINITR(NN),UIN(NN),IPBC(NBCN),
     1   GNUP1(NBCN),PBC(NBCN),UBC(NBCN),IQSOP(NSOP)
      DIMENSION CJGNUP(NBCN)
      DIMENSION QSB(NN), USB(NN), QPB(NPBC), UPB(NPBC)
      DIMENSION WMA1(NN), SMA1(NN),WMAM(NN)
      LOGICAL NWS
      DOUBLE PRECISION RHOST
      INTEGER,DIMENSION(8) :: IBTIME  !BEGIN TIME
      INTEGER,DIMENSION(8) :: IETIME  !END TIME
      REAL, DIMENSION(2) :: TIMEP 
      REAL ::TEMP
! TIMEP(1)-USER TIME; TIMEP(2)-SYSTEM TIME
      DATA RHOST/2.165D3/
      SAVE RHOST,WMAI,SMAI,IBTIME
C     RHOST -- CRYSTAL SALT DENSITY (KG/M3)
C     WMA1 -- WATER MASS IN THE PREVIOUS TIME STEP  (KG)
C     SMA1 -- SOLUTE MASS IN THE PREVIOUS TIME STEP (KG)
C     WMAM -- WATER MASS IN THE MIDDLE TIME STEP (KG) DUE TO THE CENTRAL
C             DIFFERENCIAL 
C             EQUATION USED FOR HEAT BALANCE 
C            VOL(I)*ROU(I)*POR(I)*SW(I)
C      QST  -- TOTAL WATER SOURCE AND SINK 
C      UST  -- TOTAL SOLUTE SOURCE AND SINK
C      QPT  -- TOTAL WATER IN/OUT PUT DUE TO PRESSURE
C      SPT  -- TOTAL SOLUTE IN/OUT PUT DUE TO PRESSURE
C     WMAT -- INITIAL OVERALL WATER MASS IN DOMAIN
C     SMAT -- INITIAL OVERALL SOLUTE MASS IN DOMAIN 

C     FIRST TIME COMING TO THIS SUBROUTINE
      IF (.NOT.NWS) THEN   ! IF IT IS THE FIRST TIME TO COME TO THIS SUB
         CALL DATE_AND_TIME(VALUES=IBTIME)    ! SETS THE BEGINNING TIME
            WMAI=0.D0
            SMAI=0.D0
            WMAF=0.D0
            SMAF=0.D0
            QST=0.D0
            UST=0.D0
            QPT=0.D0
            SPT=0.D0
          CALL ZERO(WMAM,NN,0.0D0)
          CALL ZERO(QSB,NN,0.0D0)
          CALL ZERO(USB,NN,0.0D0)
          CALL ZERO(QPB,NPBC,0.0D0)
          CALL ZERO(UPB,NPBC,0.0D0)
C         ITE==0 SM IS OBTAINED FROM SALT CURVE
C         ITE==1 SM IS INHERITED FROM *.ICS FILE       
C         WARNING!! THIS SALT CURVE MAY BE CHANGED! THIS IS ONLY FOR 'SOLID'
C         CONDITIONS!
        IF (ITE.EQ.0) THEN
          DO 1213 I =1,NN
            SM(I)=(1.D0-POR(I))*RHOS*VOL(I)*CS1(I)*UVEC(I)
1213      CONTINUE
        END IF

        DO 1 I=1,NN
          WMA1(I)=VOL(I)*POR(I)*SW(I)*RHO(I)
          SMA1(I)=WMA1(I)*UM1(I)
          WMAI=WMAI+WMA1(I)                   !INITIAL OVERALL WATER MASS
          SMAI=SMAI+SMA1(I)                !INITIAL OVERALL SOLUTE MASS
          WMA(I)=WMA1(I)
          SMA(I)=SMA1(I)
1       CONTINUE
C     SECOND TIME CALLING SWMASS
      ELSEIF (NWS) THEN         ! NOT THE FIRST TIME TO COME TO THIS SUB
        DO 2 I=1,NN
C          WMA1(I)=WMA(I)                             !LAST WATER MASS
C          SMA1(I)=SMA(I)                             !LAST SOLUTE MASS
C         RATE OF CHANGE IN TOTAL STORED FLUID DUE TO PRESSURE CHANGE
          TMP1=(1-ISSFLO/2)*RHO(I)*VOL(I)*
     1     (SW(I)*SOP(I)+POR(I)*DSWDP(I))*(PVEC(I)-PM1(I))   !/DELTP
C         RATE OF CHANGE IN TOTAL STORED FLUID DUE TO CONCENTRATION CHANGE
          TMP2=(1-ISSFLO/2)*POR(I)*SW(I)*DRWDU*VOL(I)*
     1     (UM1(I)-UM2(I))                                   !/DLTUM1
          WMA1(I)=WMA1(I)+TMP1+TMP2

C         RATE OF CHANGE IN SOLUTE DUE TO CONCENTRATION CHANGE
          ESRV=POR(I)*SW(I)*RHO(I)*VOL(I)
          EPRSV=(1.D0-POR(I))*RHOS*VOL(I)
          DU=(1-ISSTRA)*(UVEC(I)-UM1(I))
          SMA1(I)=SMA1(I)+ESRV*CW*DU
C         RATE OF CHANGE OF ADSORBATE
          ADSP=EPRSV*CS1(I)*DU
          SMA1(I)=SMA1(I)+ADSP
C         RATE OF CHANGE IN SOLUTE DUE TO CHANGE IN MASS OF FLUID
          SMA1(I)=SMA1(I)+CW*UVEC(I)*(1-ISSFLO/2)*VOL(I)*
     1     (RHO(I)*(SW(I)*SOP(I)+POR(I)*DSWDP(I))*DPDTITR(I)*DELTP
     2     +POR(I)*SW(I)*DRWDU*(UM1(I)-UM2(I)))
C         FIRST-ORDER PRODUCTION/DECAY OF SOLUTE
          SMA1(I)=SMA1(I)+ESRV*PRODF1*UVEC(I)
C         FIRST-ORDER PRODUCTION/DECAY OF ADSORBATE
          SMA1(I)=SMA1(I)+EPRSV*PRODS1*(SL(I)*UVEC(I)+SR(I))
C         ZERO-ORDER PRODUCTION/DECAY OF SOLUTE
          SMA1(I)=SMA1(I)+ESRV*PRODF0
C         ZERO-ORDER PRODUCTION/DECAY OF ADSORBATE
          SMA1(I)=SMA1(I)+EPRSV*PRODS0

          WMA(I)=VOL(I)*POR(I)*SW(I)*RHO(I)
          SMA(I)=WMA(I)*UVEC(I)

C         POSSIBLLY SMA COULD GO NEGTIVE DUETO OVERSHOOTING
C         THIS CAN BE AVOIDED USING SMA
C          IF (SMA1(I).LT.0.D0) SMA1(I)=SMA(I)

C         ----- THE FOLLOWING SCRITPS IS WORKING ------
C         CALCULATING SOLID SALT SM (KG) AND 
C         SO FAR THE BEST METHOD
C          SM(I)=SM(I)+ADSP

C         THIS LINE IS ADDED FOR REMOVING THE NEGATIVE WHEN SILT NEG0.2
C          IF (SM(I).LT.0.D0)  SM(I)=EPRSV*CS1(I)*UVEC(I)
C         ----- THE ABOVE SCRITPS IS WORKING ------

C         ANOTHER METHOD USING DIRECT LINKING BETWEEN C AND SM
C         SPIKE WAS FOUND USING THIS METHOD
C         THIS IS ENABLED AGAIN TO CHECK AFTER CHANGING UITER TO UM1 IN
C         BC TIME, SALT CAN DEVELOP JUST BY USING SALT CURVE 16-02-10

C          SM(I)=EPRSV*CS1(I)*UVEC(I)
C         THERE ARE ALSO SPIKES FOR THIS METHOD
C          SM(I)=EPRSV*CS1(I)*UM1(I)

C         THIS IS NEWLY FOUND EQUATION THAT STRICTLY FOLLOW SALT CURVE
C         2016-02-12 IN THIS CASE THERE WILL BE NO SM BECOMING NEGATIVE
C         IF C IS NEGATIVE
          SM(I)=EPRSV*SL(I)*UVEC(I)
C  TO190311 BELOW IS THE REFRENCE IN SUBROUTINE ADSORB TO CALCULATE
C  ADSPORTION
CC.....FREUNDLICH SORPTION MODEL                                          ADSORB........4200
C  700 IF(ADSMOD.NE.'FREUNDLICH') GOTO 950                                ADSORB........4300
C      CHCH=CHI1/CHI2                                                     ADSORB........4400
C      DCHI2=1.D0/CHI2                                                    ADSORB........4500
C      RH2=RHOW0**DCHI2                                                   ADSORB........4600
C      CHI2F=((1.D0-CHI2)/CHI2)                                           ADSORB........4700
C      DO 750 I=1,NN                                                      ADSORB........4800
C      IF(U(I)) 720,720,730                                               ADSORB........4900
C  720 UCH=1.0D0                                                          ADSORB........5000
C      GOTO 740                                                           ADSORB........5100
C  730 UCH=U(I)**CHI2F                                                    ADSORB........5200
C  740 RU=RH2*UCH                                                         ADSORB........5300
C      CS1(I)=CHCH*RU                                                     ADSORB........5400
C      CS2(I)=0.D0                                                        ADSORB........5500
C      CS3(I)=0.D0                                                        ADSORB........5600
C      SL(I)=CHI1*RU                                                      ADSORB........5700
C      SR(I)=0.D0                                                         ADSORB........5800
C          EPRSV=(1.D0-POR(I))*RHOS*VOL(I)
C   TO200313
C      SM(I)=EPRSV*SL(I)*UVEC(I)         
C      SM(I)=EPRSV*CHI1*RU*UVEC(I)                                  # 5700
C      SM(I)=EPRSV*CHI1*RH2*UCH*UVEC(I)                             # 5300
C      SM(I)=EPRSV*CHI1*RHOW0**DCHI2*UCH*UVEC(I)                    # 4600
C      SM(I)=EPRSV*CHI1*RHOW0**(  1.D0/CHI2  )*UCH*UVEC(I)          # 4500
C      SM(I)=EPRSV*CHI1*RHOW0**(  1.D0/CHI2  )*U(I)**CHI2F*UVEC(I)  # 5200
C      SM(I)=EPRSV*CHI1*RHOW0**(  1.D0/CHI2  )*U(I)**((1.D0-CHI2)/CHI2)*UVEC(I) # 4700
C      SM(I)=  (1.D0-POR(I))*RHOS*VOL(I) *CHI1*RHOW0**(  1.D0/CHI2  )*U(I)**((1.D0-CHI2)/CHI2)*UVEC(I)   # EPRSV
C      SIMPLE VERSION:
C      SM(I)= (1.D0-POR(I))*RHOS*VOL(I)   *CHI1 * RHOW0**(1.D0/CHI2)*U(I)**((1.D0-CHI2)/CHI2)*UVEC(I)
C      FROM EQUATION 2.35a in SUTRA MANUAL
C        CS=CHI1* (RHOW0*C)**(1/CHI2)
C      SO SM ESSENTIALLY IS  SM(I)= RHOS*VOL(I)*CS
C        SO in paper C_Solid=a C**b and 
C                    a = (1-POR(I))* CHI1* RHOW0**(1/CHI2)
C                    b =  1/CHI2

C          IF (UVEC(I).LE.UVM)THEN
C            SM(I)=0.0
C          ELSE
C            SM(I)=SMA1(I)-UVM*ESRV
C            IF (SM(I).LE.0.D0) SM(I)=SMA(I)-UVM*ESRV
C          ENDIF

C         GAIN/LOSS OF FLUID THROUGH FLUID SOURCES AND SINKS
          QSB(I)=QSB(I)+QIN(I)*DELTP
C         GAIN/LOSS OF SOLUTE THROUGH FLUID SOURCES AND SINKS
          USB(I)=USB(I)+QINITR(I)*CW*UIN(I)*DELTU
2     CONTINUE


      DO 200 IP=1,NPBC 
      I=IABS(IPBC(IP))
      QPB(IP)=QPB(IP)+CJGNUP(IP)*(PBC(IP)-PVEC(I))*DELTP
      IF (QPLITR(IP).LE.0D0) THEN
         UPB(IP) = UPB(IP)+ QPLITR(IP)*CW*UVEC(I)*DELTU
      ELSE                                                    
         UPB(IP) = UPB(IP)+ QPLITR(IP)*CW*UBC(IP)*DELTU
      ENDIF
  200 CONTINUE 
 1500 CONTINUE
      ENDIF
      
      IF (ISTOP.EQ.1)THEN
      DO 5 I=1,NN
      QST=QST+QSB(I)
      UST=UST+USB(I)
      WMAF=WMAF+WMA1(I)
      SMAF=SMAF+SMA1(I)
5      CONTINUE
      DO 6 I=1,NPBC
      QPT=QPT+QPB(I)
      UPT=UPT+UPB(I)
6      CONTINUE
      WRITE(21,7)
7      FORMAT(/,'MASS BALANCE')
      WRITE(21,3)WMAI,WMAF,QPT,QST,(WMAF-WMAI),QST+QPT
     1, -(WMAF-WMAI)+QST+QPT,(-(WMAF-WMAI)+QST+QPT)/(QST+QPT)
3      FORMAT('INITIAL WATER STORAGE IS (KG)',27X,'[WMAI]:'
     1,2X,1PE15.8,/
     6,'FINAL WATER STORAGE IS (KG)',29X,'[WMAF]:',2X,1PE15.8,/
     2,'TOTAL PRESSURE BOUNDARY IN(+)/OUT(-) IS (KG)',13X,'[QPT]:'
     2,2X,1PE15.8,/
     3,'TOTAL WATER SOURCE(+)/SINK(-) BOUDARY IS (KG)',11X,' [QST]:'
     4,2X,1PE15.8,/
     1,'WATER STORAGE DIFF. GAIN(+)/LOSS(-) IS (KG)   [WSDI=WMAF-WMAI]:'
     1,2X,1PE15.8,/
     1,'TOTAL WATER GAIN(+)/LOSS(-) FROM BDY. IS (KG)     [QS=QSI+QPI]:'
     1,2X,1PE15.8,/
     4,'ABSOLUTE MASS DIF. BTW STORAGE AND IN&OUT (KG)       [QS-WSDI]:'
     2,2X,1PE15.8,/
     5,'RELATIVE MASS DIF. BTW STORAGE AND IN&OUT       [(QS-WSDI)/QS]:'
     6,2X,1PE15.8,/)
      WRITE(21,8)
8      FORMAT(/,'SOLUTE BALANCE')
      WRITE(21,4)SMAI,SMAF,UPT,UST,SMAF-SMAI
     1,UPT+UST,-(SMAF-SMAI)+UST+UPT,(-(SMAF-SMAI)+UST+UPT)/(UST+UPT)
4      FORMAT('INITIAL SOLUTE STORAGE IS (KG)',25X,'[SMAI]:'
     1,2X,1PE15.8,/
     6,'FINAL SOLUTE STORAGE IS (KG)                           [SMAF]:'
     2,2X,1PE15.8,/
     2,'TOTAL PRESSURE BOUNDARY IN(+)/OUT(-) IS (KG)            [UPT]:'
     3,2X,1PE15.8,/
     3,'TOTAL SOLUTE SOURCE(+)/SINK(-) BOUDARY IS (KG)          [UST]:'
     3,2X,1PE15.8,/
     1,'SOLUTE STORAGE DIFF. GAIN(+)/LOSS(-) IS (KG) [SSDI=SMAF-SMAI]:'
     3,2X,1PE15.8,/
     1,'TOTAL SOLUTE GAIN(+)/LOSS(-) FROM BDY.   (KG)    [SS=UPT+UST]:'
     3,2X,1PE15.8,/
     4,'ABSOLUTE MASS DIF. BTW STORAGE AND IN&OUT(KG)       [SS-SSDI]:'
     3,2X,1PE15.8,/
     5,'RELATIVE MASS DIF. BTW STORAGE AND IN&OUT (KG) [(SS-SSDI)/SS]:'
     3,2X,1PE15.8,/)
C ......CALCULATE HOW MUCH TIME IS SPENT FOR FINISHING THE PROGRAM
        CALL DATE_AND_TIME(VALUES=IETIME) ! SETS THE FINISHING TIME
C        IEMP=1
        CALL ETIME(TIMEP,TEMP)  
C       TIMEP(1)-USER TIME; TIMEP(2)-SYSTEM TIME
        WRITE(21,10)IBTIME(3),IBTIME(2),IBTIME(1),IBTIME(5),IBTIME(6)
     1,IBTIME(7),IETIME(3),IETIME(2),IETIME(1),IETIME(5),IETIME(6)
     2,IETIME(7)
 10     FORMAT('PROGRAM STARTS AT:',3X,I2,'/',I2,'/',I4,3X
     1,I2,':',I2,':',I2,/,'PROGRAM FINISHES AT:',1X,I2,'/',I2,'/',I4
     2,3X,I2,':',I2,':',I2,/)
        
        IH=INT(TIMEP(1)/3600.)
        IM=INT((TIMEP(1)-3600.*IH)/60.)
        IS=TIMEP(1)-3600.*IH-60.*IM
        WRITE(21,11)IH,IM,IS
 11     FORMAT('USER TIME:',4X,I4,'H',I3,'M',I3,'S')

        IH=INT(TIMEP(2)/3600.)
        IM=INT((TIMEP(2)-3600.*IH)/60.)
        IS=TIMEP(2)-3600.*IH-60.*IM
        WRITE(21,12)IH,IM,IS
 12     FORMAT('SYSTEM TIME:',2X,I4,'H',I3,'M',I3,'S')

        IH=INT((TIMEP(1)+TIMEP(2))/3600.)
        IM=INT(((TIMEP(1)+TIMEP(2))-3600.*IH)/60.)
        IS=(TIMEP(1)+TIMEP(2))-3600.*IH-60.*IM
        WRITE(21,13)IH,IM,IS
 13     FORMAT('OVERALL TIME:',1X,I4,'H',I3,'M',I3,'S')
        ENDIF
      RETURN
      END
C ......




C *** RSC--SALT RESISTANCE
      DOUBLE PRECISION FUNCTION SALTRSIS(MSC,UM,C,DS)
      USE M_SALTR
      IMPLICIT NONE
      DOUBLE PRECISION UM,C,DS
      INTEGER MSC
C     MSC -- SALT RESISTANCE SWICH =0 OFF =1 FUJIMAKI(2006)
C     UM  -- THE SOLUBILITY [-]
C     C   -- SOLUTE CONCENTRATION [-]
C     DS  -- MASS OF SOLID SALT PER UNIT AREA[KG/M2]  TO200313
C     TO190302
C     UNIT CONVERSION: DS*1.D2 CONVERTS THE UNIT FROM KG/M2 TO MG/CM2
C     AS FUJIMAKI PAPER USES MG/CM2 AS UNIT.
C     SEE DEFINATION ONE LINE ABOVE EQ26 in FUJIMAKI 2006
C      IF ((C.LE.UM).OR.(MSC.LE.0))  THEN
      IF (MSC.LE.0)  THEN
        SALTRSIS = 0.D0
      ELSE
        SALTRSIS = (AR*DLOG(DS*1.D2+EXP(-BR/AR))+BR)*1.D2
        IF (SALTRSIS.LE.0.D0)  SALTRSIS = 0.D0 
      ENDIF
      RETURN
      END FUNCTION SALTRSIS

C
C      SUBROUTINE ETOPT(IT,DELT,NFY,ACET)
C      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
C      DIMENSION ACET(NFY)
C      IF (IT.EQ.1) THEN  
CC OUTPUT EVAPORATION RATE TO BCO.DAT
C      OPEN(21,FILE='BCO.DAT',STATUS='UNKNOWN',POSITION='APPEND')   
CC SHOUD IT BE APPENDED?
C      WRITE(21,98)
C98      FORMAT('  IT',4X,'TIME(DAY)',3X,'ETRATE(M/S)')
C      ENDIF
C      WRITE(21,99) IT, DBLE(IT)*DELT/3600./24. ,(ACET(I),I=1,NFY)
C99      FORMAT(I15,(1PE10.2,2X),500(1PE10.3,1X))
C      RETURN
C      END 





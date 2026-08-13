*******************************************************************************;
* US Life Table 2023                                                          ;
  %MACRO USMATCHD(IN=IN, OUT=OUT, TABLE='SEXRACE', INDIVIDL=0, ID=STUDY,
    AGE=AGE, MALE=MALE, OTHER=OTHER, SCALE='YEARS', MAX=100, NINC=999.9,
    TIME=TIME, SMATCHED=SMATCHED, HMATCHED=HMATCHED);


/*  Andrew Toth - 12/23/2025

  NOTE: The estimates for 2023 were different than that of 2008. For 2023, the 
        "other" catrgory consists of Black, Asian, American Indian, 
	 	and Hispanic. To get the estimates for other (non-white), we took the
        weighted average of the deaths for each of the above listed races
	    (using the Number at-risk as the weight). To keep the macro naming
        consistent, We denote the "Other" group with "B" in the HZ.  estiates


*/
*______________________________________________________________________________;
*                                                                              ;
* DEFINITIONS OF CALLING ARGUMENTS:            DEFAULT:                        ;
*                                                                              ;
*   IN       = Input data set name               IN                            ;
*   OUT      = Output data set name              OUT                           ;
*   TABLE    = Type of life table:               'SEXRACE'                     ;
*                'OVERALL' = Overall table                                     ;
*                'SEX'     = Table by gender                                   ;
*                'RACE'    = Table by race                                     ;
*                'SEXRACE' = Table by sex and race                             ;
*   INDIVIDL = Output individual curves          0                             ;
*                (default is mean curves)                                      ;
*                                                                              ;
* Input information for each patient (all must be variables on the dataset)    ;
*   ID       = Patient ID                        STUDY (SAS_variable_name)     ;
*   AGE      = Age (years)                       AGE   (SAS_variable_name)     ;
*   MALE     = Male=1, Female=0                  MALE  (SAS_variable_name)     ;
*   OTHER    = White=0, Other=1                  OTHER (SAS_variable_name)     ;
*                                                                              ;
* Output variables:                                                            ;
*   TIME     = Time axis variable name           TIME                          ;
*                (values in the units of SCALE)                                ;
*   SMATCHED = Survivorship function             SMATCHED                      ;
*   HMATCHED = Hazard function scaled in the     HMATCHED                      ;
*                units of SCALE                                                ;
*                                                                              ;
* Time scale of the life table (default is years):                             ;
* NOTE:  MAX on input and TIME and HMATCHED on output are scaled by SCALE      ;
*   SCALE    = Time scale of input and output:   'YEARS'                       ;
*                'DAYS'   = Scale in days                                      ;
*                'MONTHS' = Scale in months                                    ;
*                'YEARS'  = Scale in years                                     ;
*   MAX      = Maximum followup time             100                           ;
*   NINC     = Number of increments              999.9 (for 1001 points)       ;
*______________________________________________________________________________;
**                                                                             ;
**NOTE: NOTE: We use life table estimates of black race  and black race        ;
**stratified by male versus female as    estimate for OTHER race (race other   ;
** than WHITE)
*                                                                              ;
* Macro to test for empty data sets                                            ;
 %MACRO NUMOBS(IN);
*______________________________________________________________________________;
*                                                                              ;
* DEFINITIONS OF CALLING ARGUMENTS:                   DEFAULT:                 ;
*                                                                              ;
*   IN       = Input data set name                    IN                       ;
*   _NUM_    = On output, the number of observations  _NUM_                    ;
*______________________________________________________________________________;
*                                                                              ;
 %GLOBAL _NUM_;
 DATA _NULL_;
   IF 0 THEN SET &IN NOBS=COUNT;
   CALL SYMPUT('_NUM_', LEFT(PUT(COUNT,8.)));
 STOP;
 RUN;
 %MEND NUMOBS;
*______________________________________________________________________________;
*                                                                              ;
* Initially, compute the base survival for the age of each patient and add to  ;
* output data set.                                                             ;
*______________________________________________________________________________;
*                                                                              ;
  LIBNAME USLIFE23 '/studies/general/uslife/table2023/estimates';
*******************************************************************************;
* Overall Life Table                                                           ;
  %IF &TABLE='OVERALL' %THEN %DO;
    %HAZPRED(
    PROC HAZPRED DATA=&IN INHAZ=USLIFE23.HZICALL OUT=&OUT NOCL NONOTES;
         TIME AGE;);
    DATA &OUT; SET &OUT;
    AGESURV=_SURVIV;
    DROP _SURVIV _CLLSURV _CLUSURV _EARLYS _CONSTS _LATES _HAZARD _CLLHAZ
         _CLUHAZ _EARLYH _CONSTH _LATEH;
    %GOTO PLOT;
  %END;
*******************************************************************************;
* Life Table by gender                                                         ;
  %IF &TABLE='SEX' %THEN %DO;
* Females                                                                      ;
    DATA FEMALE; SET &IN(WHERE=(&MALE=0));
    %NUMOBS(FEMALE);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=FEMALE INHAZ=USLIFE23.HZICF OUT=FEMALE NOCL NONOTES;
         TIME AGE;);
    %END;
* Males                                                                        ;
    DATA MALE; SET &IN(WHERE=(&MALE=1));
    %NUMOBS(MALE);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=MALE INHAZ=USLIFE23.HZICM OUT=MALE NOCL NONOTES;
         TIME AGE;);
    %END;

    DATA &OUT; SET MALE FEMALE;
    AGESURV=_SURVIV;
    DROP _SURVIV _CLLSURV _CLUSURV _EARLYS _CONSTS _LATES _HAZARD _CLLHAZ
         _CLUHAZ _EARLYH _CONSTH _LATEH;
    %GOTO PLOT;
  %END;
*******************************************************************************;
* Life Table by ethnicity                                                      ;
  %IF &TABLE='RACE' %THEN %DO;
* Whites                                                                       ;
    DATA WHITE; SET &IN(WHERE=(&OTHER=0));
    %NUMOBS(WHITE);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=WHITE INHAZ=USLIFE23.HZICW OUT=WHITE NOCL NONOTES;
         TIME AGE;);
    %END;
* Other races: here we use estimate of black race as estimate for other race ;
    DATA OTHER; SET &IN(WHERE=(&OTHER=1));
    %NUMOBS(OTHER);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=OTHER INHAZ=USLIFE23.HZICB OUT=OTHER NOCL NONOTES;
         TIME AGE;);
    %END;

    DATA &OUT; SET WHITE OTHER;
    AGESURV=_SURVIV;
    DROP _SURVIV _CLLSURV _CLUSURV _EARLYS _CONSTS _LATES _HAZARD _CLLHAZ
         _CLUHAZ _EARLYH _CONSTH _LATEH;
    %GOTO PLOT;
  %END;
*******************************************************************************;
* Life Table by gender and ethnicity                                           ;
  %IF &TABLE='SEXRACE' %THEN %DO;
* White males                                                                  ;
    DATA WM; SET &IN(WHERE=(&MALE=1 AND &OTHER=0));
    %NUMOBS(WM);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=WM INHAZ=USLIFE23.HZICWM OUT=WM NOCL NONOTES;
         TIME AGE;);
    %END;
* Other males                                                                  ;
    DATA OM; SET &IN(WHERE=(&MALE=1 AND &OTHER=1));
    %NUMOBS(OM);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=OM INHAZ=USLIFE23.HZICBM OUT=OM NOCL NONOTES;
         TIME AGE;);
    %END;
* White females                                                                ;
    DATA WF; SET &IN(WHERE=(&MALE=0 AND &OTHER=0));
    %NUMOBS(WF);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=WF INHAZ=USLIFE23.HZICWF OUT=WF NOCL NONOTES;
         TIME AGE;);
    %END;
* Other females                                                                ;
    DATA OF; SET &IN(WHERE=(&MALE=0 AND &OTHER=1));
    %NUMOBS(OF);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=OF INHAZ=USLIFE23.HZICBF OUT=OF NOCL NONOTES;
         TIME AGE;);
    %END;

    DATA &OUT; SET WM OM WF OF;
    AGESURV=_SURVIV;
    DROP _SURVIV _CLLSURV _CLUSURV _EARLYS _CONSTS _LATES _HAZARD _CLLHAZ
         _CLUHAZ _EARLYH _CONSTH _LATEH;
    %GOTO PLOT;
  %END;
*******************************************************************************;
* We should not be here, so get out                                            ;
  %GOTO ERROR;
*______________________________________________________________________________;
*                                                                              ;
* Generate time points                                                         ;
*______________________________________________________________________________;
*                                                                              ;
  %PLOT:;
  INC=&MAX/&NINC;
* Determine scaling (NOTE:  Hazard will be scaled in units of SCALE)           ;
  SCALEF=.;
  %IF &SCALE='YEARS' %THEN %DO; SCALEF=1; %GOTO CALC; %END;
  %IF &SCALE='MONTHS' %THEN %DO; SCALEF=1/12; %GOTO CALC; %END;
  %IF &SCALE='DAYS' %THEN %DO; SCALEF=1/365.2425; %GOTO CALC; %END;
*******************************************************************************;
* We should not be here, so get out                                            ;
  %GOTO ERROR;
*******************************************************************************;
* Generate time axis in units of SCALE                                         ;
  %CALC:;
  DO &TIME=0 TO &MAX BY INC, &MAX;
    YEARS=&TIME*SCALEF;
    AGE_YR=YEARS + &AGE;
    OUTPUT;
  END;
*______________________________________________________________________________;
*                                                                              ;
* Normalized life table curves                                                 ;
*______________________________________________________________________________;
*                                                                              ;
* Overall Life Table                                                           ;
  %IF &TABLE='OVERALL' %THEN %DO;
    %HAZPRED(
    PROC HAZPRED DATA=&OUT INHAZ=USLIFE23.HZICALL OUT=&OUT NOCL NONOTES; TIME AGE_YR;);
    DATA &OUT; SET &OUT;
    &SMATCHED=_SURVIV/AGESURV;
    &HMATCHED=_HAZARD;
    DROP _SURVIV _CLLSURV _CLUSURV _EARLYS _CONSTS _LATES _HAZARD _CLLHAZ
         _CLUHAZ _EARLYH _CONSTH _LATEH;
    %GOTO DONE;
  %END;
*******************************************************************************;
* Life Table by gender                                                         ;
  %IF &TABLE='SEX' %THEN %DO;
* Females                                                                      ;
    DATA FEMALE; SET &OUT(WHERE=(&MALE=0));
    %NUMOBS(FEMALE);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=FEMALE INHAZ=USLIFE23.HZICF OUT=FEMALE NOCL NONOTES;
           TIME AGE_YR;);
    %END;
* Males                                                                        ;
    DATA MALE; SET &OUT(WHERE=(&MALE=1));
    %NUMOBS(MALE);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=MALE INHAZ=USLIFE23.HZICM OUT=MALE NOCL NONOTES;
           TIME AGE_YR;);
    %END;

    DATA &OUT; SET MALE FEMALE;
    &SMATCHED=_SURVIV/AGESURV;
    &HMATCHED=_HAZARD;
    DROP _SURVIV _CLLSURV _CLUSURV _EARLYS _CONSTS _LATES _HAZARD _CLLHAZ
         _CLUHAZ _EARLYH _CONSTH _LATEH;
    PROC DELETE DATA=FEMALE MALE;
    %GOTO DONE;
  %END;
*******************************************************************************;
* Life Table by ethnicity                                                      ;
  %IF &TABLE='RACE' %THEN %DO;
* Whites                                                                       ;
    DATA WHITE; SET &OUT(WHERE=(&OTHER=0));
    %NUMOBS(WHITE);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=WHITE INHAZ=USLIFE23.HZICW OUT=WHITE NOCL NONOTES;
           TIME AGE_YR;);
    %END;
* Other races                                                                  ;
    DATA OTHER; SET &OUT(WHERE=(&OTHER=1));
    %NUMOBS(OTHER);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=OTHER INHAZ=USLIFE23.HZICB OUT=OTHER NOCL NONOTES;
           TIME AGE_YR;);
    %END;

    DATA &OUT; SET WHITE OTHER;
    &SMATCHED=_SURVIV/AGESURV;
    &HMATCHED=_HAZARD;
    DROP _SURVIV _CLLSURV _CLUSURV _EARLYS _CONSTS _LATES _HAZARD _CLLHAZ
         _CLUHAZ _EARLYH _CONSTH _LATEH;
    PROC DELETE DATA=WHITE OTHER;
    %GOTO DONE;
  %END;
*******************************************************************************;
* Life Table by gender and ethnicity                                           ;
  %IF &TABLE='SEXRACE' %THEN %DO;
* White males                                                                  ;
    DATA WM; SET &OUT(WHERE=(&MALE=1 AND &OTHER=0));
    %NUMOBS(WM);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=WM INHAZ=USLIFE23.HZICWM OUT=WM NOCL NONOTES;
           TIME AGE_YR;);
    %END;
* Other males                                                                  ;
    DATA OM; SET &OUT(WHERE=(&MALE=1 AND &OTHER=1));
    %NUMOBS(OM);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=OM INHAZ=USLIFE23.HZICBM OUT=OM NOCL NONOTES;
           TIME AGE_YR;);
    %END;
* White females                                                                ;
    DATA WF; SET &OUT(WHERE=(&MALE=0 AND &OTHER=0));
    %NUMOBS(WF);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=WF INHAZ=USLIFE23.HZICWF OUT=WF NOCL NONOTES;
           TIME AGE_YR;);
    %END;
* Other females                                                                ;
    DATA OF; SET &OUT(WHERE=(&MALE=0 AND &OTHER=1));
    %NUMOBS(OF);
    %IF &_NUM_>0 %THEN %DO;
      %HAZPRED(
      PROC HAZPRED DATA=OF INHAZ=USLIFE23.HZICBF OUT=OF NOCL NONOTES;
           TIME AGE_YR;);
    %END;

    DATA &OUT; SET WM OM WF OF;
    &SMATCHED=_SURVIV/AGESURV;
    &HMATCHED=_HAZARD;
    DROP _SURVIV _CLLSURV _CLUSURV _EARLYS _CONSTS _LATES _HAZARD _CLLHAZ
         _CLUHAZ _EARLYH _CONSTH _LATEH;
    PROC DELETE DATA=WM OM WF OF;
    %GOTO DONE;
  %END;
*******************************************************************************;
* We should not be here, so get out                                            ;
  %GOTO ERROR;
*******************************************************************************;
* Normalize to age at time zero                                                ;
  %DONE:;
  %IF &INDIVIDL=0 %THEN %DO;
    DATA &OUT; SET &OUT;
    &HMATCHED=&HMATCHED*&SMATCHED; /* Density, for getting mean hazard */
*______________________________________________________________________________;
*                                                                              ;
* Sum life table over all values                                               ;
*______________________________________________________________________________;
*                                                                              ;
    PROC SUMMARY DATA=&OUT NWAY; CLASS &TIME; VAR &SMATCHED &HMATCHED;
         OUTPUT OUT=&OUT MEAN=&SMATCHED &HMATCHED;
    DATA &OUT; SET &OUT;
    &HMATCHED=&HMATCHED/&SMATCHED;
  %END;
*______________________________________________________________________________;
*                                                                              ;
* Finished                                                                     ;
  %ERROR:;
  %MEND;
*******************************************************************************;




%macro MCO_OCCUPANCY(start=18, end=23);

/* ======================================
   INIT MULTI YEAR DAILY TABLE
   ====================================== */
data work.DAILY_OCCUPANCY_ALL;
    length AUT_TYP_UM $3 ETA_NUM $9;
    format SDATE date9.;
    format TX_OCCUP_JOUR 8.4;
    stop;
run;

/* ======================================
   YEAR LOOP
   ====================================== */
%do an=&start %to &end;

%let annee = 20&an.;

    %put PROCESSING YEAR 20&an;

    /* ----------------------------------
       1) BASE STAYS
       ---------------------------------- */

%let an_next = %eval(&an +1);
/*,"29","56","22"*/
%let dep_filter = substr(ETA_NUM,1,2) in ("35");
%let eta_filter = ETA_NUM ="350005179";
%let ent_filter = substr(ENT_DAT,5,4);

data work.sBase_&an.a;
    set 
        ORAVUE.T_MCO&an.C
            (where=(&eta_filter))

        ORAVUE.T_MCO&an_next.C
            (where=(&eta_filter and &ent_filter));

    ENT_ANN = substr(ENT_DAT,5,4);
    SOR_ANN = substr(SOR_DAT,5,4);
    LOS     = (EXE_SOI_DTF - EXE_SOI_DTD)/86400;
run;

    /* ----------------------------------
       2) ORDER VARIABLE
       ---------------------------------- */
    %if &an < 19 %then %do;
        %let ord_var1 = UM_ORD_NUM;
        %let ord_var2 = UM_ORD_NUM;
    %end;
    %else %if &an = 19 %then %do;
        %let ord_var1 = UM_ORD_NUM;
        %let ord_var2 = RUM_ORD_NUM;
    %end;
    %else %do;
        %let ord_var1 = RUM_ORD_NUM;
        %let ord_var2 = RUM_ORD_NUM;
    %end;
    /* ----------------------------------
       3) JOIN UM
       ---------------------------------- */
  proc sql;
create table work.sMCO_&an as
select
    C.*,
    coalesce(U19.AUT_TYP1_UM, U20.AUT_TYP1_UM) as AUT_TYP1_UM,
    coalesce(U19.&ord_var1, U20.&ord_var2) as RUM_ORD_NUM,
    coalesce(U19.PAR_DUR_SEJ, U20.PAR_DUR_SEJ) as PAR_DUR_SEJ
from work.sBase_&an.a as C
left join ORAVUE.T_MCO&an.UM as U19
  on C.ETA_NUM = U19.ETA_NUM
 and C.RSA_NUM = U19.RSA_NUM

left join ORAVUE.T_MCO&an_next.UM as U20
  on C.ETA_NUM = U20.ETA_NUM
 and C.RSA_NUM = U20.RSA_NUM

where C.ETA_NUM = "350005179"
order by C.ETA_NUM, C.RSA_NUM, RUM_ORD_NUM;
quit;


    /* ----------------------------------
       4) COMPUTE ENTRY AND EXIT DATES
       ---------------------------------- */
    data work.sMCO_&an._DATEE;
        set work.sMCO_&an;
        by ETA_NUM RSA_NUM RUM_ORD_NUM;
        retain prev_date prev_dur;
        format DATE_E DATE_S datetime20.;

        if first.RSA_NUM then DATE_E = EXE_SOI_DTD;
        else DATE_E = prev_date + prev_dur * 86400;

        if missing(PAR_DUR_SEJ) then DATE_S = EXE_SOI_DTF;
        else DATE_S = DATE_E + PAR_DUR_SEJ * 86400;

        prev_date = DATE_E;
        prev_dur  = PAR_DUR_SEJ;
    run;

    /* ----------------------------------
       5) CONVERT TO DAILY DATES
       ---------------------------------- */
    data work.sMCO_&an._JOUR;
        set work.sMCO_&an._DATEE;
        DATE_E_J = datepart(DATE_E);
        DATE_S_J = datepart(DATE_S);
        keep ETA_NUM AUT_TYP1_UM RSA_NUM DATE_E_J DATE_S_J;
    run;

    /* ----------------------------------
       6) EXTENDED ISO CALENDAR
       ---------------------------------- */
     data work.sCALENDAR_&an.;
        format SDATE date9.;
        do SDATE = mdy(1,1,20&an)
                 to intnx('year',mdy(1,1,20&an),1)-1;
            output;
        end;
    run;

    /* ----------------------------------
       7) DAILY PATIENT COUNTS
       ---------------------------------- */
    proc sql;
    create table work.daily_&an as
    select
        C.SDATE,
        M.ETA_NUM,
        substr(M.AUT_TYP1_UM,1,3) as AUT_TYP_UM,
        count(distinct M.RSA_NUM) as NB_PAT
    from work.calendar_&an as C
    left join work.sMCO_&an._JOUR as M
        on M.DATE_E_J <= C.SDATE
       and C.SDATE <= M.DATE_S_J
    group by C.SDATE, M.ETA_NUM, calculated AUT_TYP_UM;
    quit;

    /* ----------------------------------
       8) ADD BEDS AND DAILY OCCUPANCY
       ---------------------------------- */
    proc sql;
    create table work.daily_occ_&an as
    select
        D.SDATE,
        D.ETA_NUM,
        D.AUT_TYP_UM,
        D.NB_PAT,
        sum(S.NBR_LIT_UM) as NBR_LIT_UM,
        D.NB_PAT / sum(S.NBR_LIT_UM) as TX_OCCUP_JOUR
    from work.daily_&an as D
    left join ORAVUE.T_MCO&an.SUP_IUM as S
        on D.ETA_NUM = S.ETA_NUM
       and D.AUT_TYP_UM = S.AUT_TYP_UM
    group by D.SDATE, D.ETA_NUM, D.AUT_TYP_UM, D.NB_PAT;
    quit;

    /* ----------------------------------
       9) APPEND MULTI YEAR
       ---------------------------------- */
    proc append base=work.DAILY_OCCUPANCY_ALL
                data=work.daily_occ_&an
                force;
    run;

%end;

/* ======================================
   FINAL WEEKLY AGGREGATION
   ====================================== */
proc sql;
create table work.WEEKLY_OCCUPANCY_ALL as
select
	ETA_NUM,
    AUT_TYP_UM,
    intnx('week.1', SDATE, 0, 'b') as SEMAINE format=date9.,
    mean(TX_OCCUP_JOUR) as TX_OCCUP_SEMAINE format=8.4,
    count(TX_OCCUP_JOUR) as NB_JOURS
from work.DAILY_OCCUPANCY_ALL
group by ETA_NUM, AUT_TYP_UM, calculated SEMAINE
having NB_JOURS = 7;
quit;

%mend;

%MCO_OCCUPANCY(start=18, end=23);

proc sql;
    create table WORK.NB_PAT_SEMAINE_GRAPHb as
    select distinct
        SEMAINE,
        AUT_TYP_UM,
        mean(TX_Occup_semaine) as TX_Occup_semaine
    from work.WEEKLY_OCCUPANCY_ALL
	where AUT_TYP_UM in ('01A','02B','03A') 
	group by 
        AUT_TYP_UM,
        SEMAINE
    order by
        AUT_TYP_UM,
        SEMAINE;
quit;

proc sgplot data=WORK.NB_PAT_SEMAINE_GRAPHb;
    series x=SEMAINE y=TX_Occup_semaine / group=AUT_TYP_UM;
    xaxis label="" type=time;
    yaxis label="Taux d'occupation";
    title "Taux d'occupation moyen hebdomadaire";
run;


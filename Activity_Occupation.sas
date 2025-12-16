
/*********activité hospitalière, virus et affections respiratoires ********/


/*%do loop = &start %to &end;*/

/* librairie */
%let Fichiers=%sysget(HOME)/sasdata;

%let annee = 2020; /* Param tre   indiquer : ann e sur laquelle on veut calculer les taux Transfert */
%let anneem1 = %eval(&annee-1 );
%let anneep1 = %eval(&annee+1 );
%let an = %substr(&annee,3,2);
%let anp1 = %substr(&anneep1,3,2); /* table infra annuelle */

/*liste des finessgeo en doublons avant 2018*/
%let AP = ('130780521', '130783236', '130783293', '130784234', '130804297','130784259',
'600100101', '750041543', '750100018', '750100042', '750100075', '750100083',
'750100091', '750100109', '750100125', '750100166', '750100208', '750100216',
'750100232', '750100273', '750100299', '750801441', '750803447', '750803454',
'910100015', '910100023', '920100013', '920100021', '920100039', '920100047',
'920100054', '920100062', '930100011', '930100037', '930100045', '940100027',
'940100035', '940100043', '940100050', '940100068', '950100016', '690783154',
'690784137', '690784152', '690784178', '690787478', '830100558');

/* Les affections de l'appareil respiratoire se trouvent en CMD 04 */

/* A mettre en rapport avec les CIM-10 (diagnostiques) */

proc sql;
create table ORAUSER.RespBase_2020a as
select a.ETA_NUM, a.RSA_NUM, a.NIR_ANO_17,
b.AGE_ANN, b.COD_SEX, b.GHS_NUM, b.GRG_GHM, 
substr(a.ETA_NUM,1,2) as DEP,
substr(b.GRG_GHM,1,2) as CMD, 
substr(b.GRG_GHM,6,1) as GRAV,
b.DGN_PAL,
a.EXE_SOI_DTD, a.EXE_SOI_DTF,
(a.EXE_SOI_DTF-a.EXE_SOI_DTD)/86400 as LOS
from ORAVUE.T_MCO20C a
left join ORAVUE.T_MCO20B b 
on a.ETA_NUM = b.ETA_NUM  and a.RSA_NUM = b.RSA_NUM;
quit;


data ORAUSER.RespBase_2020; 
set ORAUSER.RespBase_2020a;
/*if CMD='04';*/
LOS=(EXE_SOI_DTF-EXE_SOI_DTD)/86400;
run;

/* Questionement sur l'occupancy d'une unité médicale */

/* Nécessite :
1) une concatenation entre la base T_MCO20C et T_MCO20UM, sur la base de RSA_NUM et ETA_NUM 
2) le calcul de la SDATE d'arrivée dans l'UM:
	- Ordoné par RUM_ORD_NUM
	- première UM: DATE_E=EXE_SOI_DTD 
	- nième UM : DATE_E = DATE_E + PAR_DUR_SEJ
	- test: pour dernier UM : DATE_E = EXE_SOI_DTF
3) obtenir une table avec l'um et son nombre de patient par jour 
	- Créer un vecteur de SDATE 365 jours : "day"
	- Si DATE_E>=day>=Date_S alors incrementer NbPat pour l'um 
4) Agréger au niveau de l'autorisation médicale

*/

/* 1) Concaténation entre T_MCO20C et T_MCO20UM sur RSA_NUM et ETA_NUM */
proc sql;
create table ORAUSER.MCO20 as select 
	C.*, U.NUM_ANO_UM, 
	U.AUT_TYP1_UM, 
	U.RUM_ORD_NUM,
	U.PAR_DUR_SEJ
    from ORAUSER.RespBase_2020 as C
    inner join ORAVUE.T_MCO20UM as U
        on C.RSA_NUM = U.RSA_NUM
       and C.ETA_NUM  = U.ETA_NUM
    order by C.ETA_NUM, C.RSA_NUM, U.RUM_ORD_NUM;
quit;


/* 2) Calcul de la SDATE d'arrivée dans l'UM (DATE_E) */
/* Calcul itératif de DATE_E en SDATEtime */
data ORAUSER.MCO20_DATEE;
  set ORAUSER.MCO20;
  by ETA_NUM RSA_NUM RUM_ORD_NUM;
  /* variables de rétention pour l'itération */
  retain prev_date_e prev_par_dur;
  format prev_date_e SDATEtime20.;
  format DATE_E SDATEtime20.;
  format DATE_S SDATEtime20.;
  /* si nouvelle hospitalisation (nouvel ETA_NUM) : starter */
	  if first.ETA_NUM or first.RSA_NUM then do;
	      DATE_E = EXE_SOI_DTD;
		  DATE_S = DATE_E + PAR_DUR_SEJ * 24 * 60 * 60;
		if missing(PAR_DUR_SEJ) then do;
		  DATE_S = EXE_SOI_DTF;
		end;
	  end;
	  else do;
	    /* sécurité : si prev_par_dur manquant -> 0 */
	    if missing(prev_par_dur) then prev_par_dur = 0;
	    /* prev_par_dur est en jours -> convertir en secondes */
	    DATE_E = prev_date_e + prev_par_dur * 24 * 60 * 60;
		DATE_S = DATE_E + PAR_DUR_SEJ * 24 * 60 * 60;
	  end;
  /* mettre à jour les valeurs "précédentes" pour la prochaine itération */
  prev_date_e  = DATE_E;
  prev_par_dur = PAR_DUR_SEJ;
run;

/* 3) obtenir une table avec l'um et son nombre de patient par jour*/

/* 3.1. Génération du vecteur des jours de l’année 2020 */
data ORAUSER.CALENDAR_2020;
    format SDATE DATE9.;
    do SDATE = '01JAN2020'd to '31DEC2020'd;
        output;
    end;
run;

/* 3.2. Transformation des SDATEtime en SDATE (pour comparaison plus simple) */
data ORAUSER.MCO20_DATEE_JOUR;
    set ORAUSER.MCO20_DATEE;
    format DATE_E_J DATE_S_J DATE9.;
    DATE_E_J = datepart(DATE_E);
    DATE_S_J = datepart(DATE_S);
    keep ETA_NUM NUM_ANO_UM AUT_TYP1_UM NIR_ANO_17 RSA_NUM GRG_GHM RUM_ORD_NUM AGE_ANN COD_SEX LOS
	DATE_E_J DATE_S_J;
run;

proc contents data=ORAUSER.MCO20_DATEE_JOUR;
run;

proc sql ;
create table WORK.Counts_Resp as
select
count(*) as Nb_lines
from ORAUSER.MCO20_DATEE_JOUR;
quit;


/* 3.3. Expension des SDATEs pour obtenir les jours de présence des patients*/
data ORAUSER.OCCUPANCY_RAW;
    set ORAUSER.mco20_datee_jour;
    do SDATE = DATE_E_J to DATE_S_J  by 86400;
    output;
	end;
run;

proc sql ;
create table WORK.Count_occup as
select
count(*) as Nb_lines
from ORAUSER.OCCUPANCY_RAW;
quit;

/* 3.4. Comptage du nombre de patients présents par UM et par jour */
proc sql;
    create table ORAUSER.OCCUPANCY_UM as
    select 
        ETA_NUM,
        NUM_ANO_UM,
		AU_TYP1_UM
        SDATE,
        count(distinct RSA_NUM) as NB_PAT
    from ORAUSER.OCCUPANCY_RAW
    group by ETA_NUM, NUM_ANO_UM, SDATE
    order by ETA_NUM, NUM_ANO_UM, SDATE;
quit;


/* 3.5. Liste complète des combinaisons UM x jour */
proc sql;
    create table ORAUSER.UM_CALENDAR as
    select distinct 
        M.ETA_NUM,
        M.NUM_ANO_UM,
        C.SDATE
    from ORAVUE.T_MCO20SUP_IUM as M,
         ORAUSER.CALENDAR_2020 as C;
quit;

/* 3.6. Comptage du nombre de patients présents, puis jointure pour remplir les zéros */
/* 3.6.1: Aggregation patient counts */
proc sql;
    create table ORAUSER.OCCUPANCY_COUNTS as
    select 
        ETA_NUM,
        NUM_ANO_UM,
        SDATE,
        count(distinct RSA_NUM) as NB_PAT
    from ORAUSER.OCCUPANCY_RAW
    group by ETA_NUM, NUM_ANO_UM, SDATE;
quit;

/* 3.6.2: Remplissage de zéros */
proc sql;
    create table ORAUSER.OCCUPANCY_UM_Z as
    select 
        UC.ETA_NUM,
        UC.NUM_ANO_UM,
        UC.SDATE,
        coalesce(O.NB_PAT, 0) as NB_PAT
    from ORAUSER.UM_CALENDAR as UC
    left join ORAUSER.OCCUPANCY_COUNTS as O
      on UC.ETA_NUM = O.ETA_NUM
     and UC.NUM_ANO_UM = O.NUM_ANO_UM
     and UC.SDATE = O.SDATE
    order by UC.ETA_NUM, UC.NUM_ANO_UM, UC.SDATE;
quit;


proc sql;
    create table ORAUSER.OCCUPANCY_UM_JR as
    select 
        UC.ETA_NUM,
        UC.NUM_ANO_UM,
        UC.SDATE,
        UC.NB_PAT,
		O.AUT_TYP_UM,
		O.NBR_LIT_UM
    from ORAUSER.OCCUPANCY_UM_Z as UC
    left join ORAUSER.T_MCO20SUP_IUM as O
      on UC.ETA_NUM = O.ETA_NUM
     and UC.NUM_ANO_UM = O.NUM_ANO_UM
    order by UC.ETA_NUM, UC.NUM_ANO_UM, UC.SDATE, O.AUT_TYP_UM;
quit;


proc sql;
    create table ORAUSER.AVERAGE_OCCUPANCY_WEEKLY as
    select distinct 
        T1.ETA_NUM,
        T1.NUM_ANO_UM,
		T1.AUT_TYP_UM,
		T1.NBR_LIT_UM,
        /* --- Étape 1: Calcule le numéro de semaine (Numérique) --- */
        /* PUT(SDATE, WEEKU.) convertit la date en chaîne de semaine (ex: '01'). */
        /* INPUT(...) convertit cette chaîne en valeur Numérique (ex: 1). */
		intnx('week',datepart(T1.SDATE), 0, 'b') as NUM_SEMAINE format=date9.,
        /* Étape 2: Calcule la moyenne de l'occupation */
        sum(T1.NB_PAT) as NB_PAT_SEMAINE
    from ORAUSER.OCCUPANCY_UM_JR as T1
    group by
        T1.ETA_NUM,
        T1.NUM_ANO_UM,
        /* --- CORRECTION ICI: Utilisation de CALCULATED NUM_SEMAINE --- */
        NUM_SEMAINE
    order by
        T1.ETA_NUM,
        T1.NUM_ANO_UM,
        NUM_SEMAINE;
quit;

proc sql;
    create table WORK.NB_PAT_SEMAINE_GRAPH as
    select
        ETA_NUM,
		NUM_SEMAINE as SEMAINE,
		AUT_TYP_UM,
        mean(NB_PAT_SEMAINE)/(NBR_LIT_UM*7) as TX_Occup_semaine
    from ORAUSER.AVERAGE_OCCUPANCY_WEEKLY
    group by ETA_NUM, SEMAINE, AUT_TYP_UM
    order by AUT_TYP_UM, TX_Occup_semaine, ETA_NUM, SEMAINE;
quit;


proc sql;
    create table WORK.NB_PAT_SEMAINE_GRAPHb as
    select
        SEMAINE,
        AUT_TYP_UM,
        mean(TX_Occup_semaine) as TX_mean_Occup_semaine
    from WORK.NB_PAT_SEMAINE_GRAPH
    group by
        SEMAINE,
        AUT_TYP_UM
    order by
        AUT_TYP_UM,
        SEMAINE;
quit;


proc sql;
    create table WORK.NB_PAT_SEMAINE_GRAPHb as
    select
		SEMAINE,
		AUT_TYP_UM,
        mean(TX_Occup_semaine) as TX_mean_Occup_semaine
    from WORK.NB_PAT_SEMAINE_GRAPH
    group by SEMAINE, AUT_TYP_UM
    order by AUT_TYP_UM, SEMAINE, TX_Occup_semaine;
quit;


ods graphics / maxobs=10009002;

proc sgplot data=WORK.NB_PAT_SEMAINE_GRAPH;
    series x=SEMAINE y=TX_Occup_semaine / group=AUT_TYP_UM;
    xaxis label="Semaine" type=time;
    yaxis label="NB_PAT moyen";
    title "NB_PAT moyen hebdomadaire";
run;

ods graphics / reset;

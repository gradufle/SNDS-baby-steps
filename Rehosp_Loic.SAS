

/* !ATTENTION, probablement beug car indice -40pt apr s 2020 !*/
/* Needs proofreading */

%macro all_years(start=13,end=22);

%do loop = &start %to &end;

%let AN					= &loop.;   /* Ann e d analyse MCO (sorties) */
%let ANP1 = %eval(&AN+1);

%let FENETRE_AVAL      = 7;      /* Fen tre en jours pour SSR/HAD d aval */
%let AJOUT_NPLUS1      = OUI;    /* Inclure janvier-f vrier N+1 c t  aval : OUI/NON */

%let EXCLU_ETAB_AP = (
  '130780521','130783236','130783293','130784234','130804297','130784259',
  '600100101','750041543','750100018','750100042','750100075','750100083',
  '750100091','750100109','750100125','750100166','750100208','750100216',
  '750100232','750100273','750100299','750801441','750803447','750803454',
  '910100015','910100023','920100013','920100021','920100039','920100047',
  '920100054','920100062','930100011','930100037','930100045','940100027',
  '940100035','940100043','940100050','940100068','950100016','690783154',
  '690784137','690784152','690784178','690787478','830100558'
);

/* Conditions d exclusion  patients  (centralisées) */
%let COND_EXCLU_PAT = 
      AGE_ANN >= 18
  and substr(BDI_COD,1,2) not in ('99','9E','9G','9H','9J') /* Exclusion des DOM */
  and substr(BDI_COD,3,3) not in ('999', '000', '099');
/* Conditions d exclusion  s jours MCO index  : pas d c s, pas transfert direct */
%let COND_MCO_INDEX = SOR_MOD not in ('6','7','9');
/* Garder les séjours en chirurgie*/ 
%let COND_CHIR = substr(GHM_NUM,3,1) in ('C', 'K');
/* Conditions sur les  tablissements */
%let COND_ETAB_NONAP   = a.ETA_NUM not in &EXCLU_ETAB_AP.;
%let COND_SEJ_NONB     = (SEJ_TYP^="B" or missing(SEJ_TYP)); /* Presta inter-établissements*/
/* Qualit  de cha nage */
%let COND_CHAINAGE_OK  = (NIR_RET='0' and NAI_RET='0' and SEX_RET='0'
                          and SEJ_RET='0' and FHO_RET='0' and PMS_RET='0');
/* Diagnostics valides */
%let COND_DGN_PAL_OK   = not missing(DGN_PAL) and DGN_PAL not in ('RSSABS','XXXX');
%let COND_DGN_REL_OK   = not missing(DGN_REL) and DGN_REL ne 'XXXX';
%let COND_ASS_DGN_OK   = not missing(ASS_DGN) and ASS_DGN not in ('XXXX');
/* Soins palliatifs */
%let COND_NO_SOIN_PALL = (GHM_NUM not in ('23Z02Z','23Z02T'));
/* Typologie s jours */
%let COND_NO_SEANCE    = substr(GHM_NUM,1,2) not in ('28','90');
%let COND_NO_OBS_TRANS = substr(GHM_NUM,1,2) not in ('14','15','27');
%let COND_NO_AMBU_SPEC = substr(GHM_NUM,1,5) not in 
                         ('11K02','17M05','17M06','17K04','17K05',
                          '17K06','17K08','17K09','23M09');
%let COND_NO_CATARACTE = substr(GHM_NUM,1,5) not in ('02C05','02C12');
/* Patients */
%let COND_ADULT        = AGE_ANN >= 18;
%let COND_DOMICILE_FR  = substr(BDI_COD,1,2) not in ('99','9E','9G','9H','9J');
%let COND_GEO_PRECIS   = substr(BDI_COD,3,3) ^= '999';
/* Mode de sortie */
%let COND_SORTIE_VIE   = SOR_MOD not in ('9');           /* exclure d c s */
%let COND_NO_TRANSFERT = SOR_MOD not in ('0','6','7');
/* Mode d entr e */
%let COND_ENT_DOM      = ENT_MOD not in ('8');
/* Temporalit  */
%let COND_WINDOW       = (AN in (&AN-1,&AN,&AN+1)); /* avec restriction jan-f v pour N+1 */
%let COND_NO_HOSP30AV  = ();
%let COND_NOT_FIRST    = not first.NIR_ANO_17;      /* pas 1er s jour de l ann e */
/* RH30 stricte */
%let COND_RH30         = ();

/* Elimination des tables dans SASDATA1 */

%macro drop_table_if_exists(lib, table);
  %if %sysfunc(exist(&lib..&table)) %then %do;
    proc sql;
      drop table &lib..&table;
    quit;
    %put NOTE: Table &lib..&table dropped.;
  %end;
%mend drop_table_if_exists;

  %drop_table_if_exists(SASDATA1, _MCO_INDEX_&AN);
  %drop_table_if_exists(SASDATA1, _AVAL_&AN);
  %drop_table_if_exists(SASDATA1, _MIN_ENTREE_&AN);
  %drop_table_if_exists(SASDATA1, _SUIVI_AVAL_&AN);
  %drop_table_if_exists(SASDATA1, IND_AVAL_RES_&AN);
  %drop_table_if_exists(SASDATA1, IND_AVAL_DETAIL_&AN);
  %drop_table_if_exists(SASDATA1, IND_AVAL_GLOBAL_&AN);
  %drop_table_if_exists(SASDATA1, MCO_&AN);
  %drop_table_if_exists(SASDATA1, SSR_&AN);
  %drop_table_if_exists(SASDATA1, MG_&AN);
  %drop_table_if_exists(SASDATA1, HAD_&AN);
  %drop_table_if_exists(SASDATA1, SSR_&ANP1);
  %drop_table_if_exists(SASDATA1, HAD_&ANP1);
  %drop_table_if_exists(SASDATA1, CONSO);
  
/* Normalisation des GHM, création de tables de référence*/

proc sql;
  create table SASDATA1.RHOSP_&AN as
  select
    a.NIR_ANO_17 as num_ano,
    datepart(a.EXE_SOI_DTD) as dt_entree format=date9.,
	c.GHM_NUM
  from ORAVUE.T_MCO&AN.C a
  left join ORAVUE.T_MCO&AN.B b on a.RSA_NUM = b.RSA_NUM and a.ETA_NUM=b.ETA_NUM 
  left join ORAVUE.T_MCO&AN.D d on a.RSA_NUM = d.RSA_NUM and a.ETA_NUM=d.ETA_NUM 
  /* Join to get GHM_NUM */
%if &AN < 15 %then %do;
  %let suffix_code = %eval(67 + (20&AN. - 2011)); /* GHM pour N*/
  %let suffix = %sysfunc(byte(&suffix_code));
  %let gv_table = ORAVUE.T_MCO&AN.GV11&suffix;
  left join &gv_table c on a.ETA_NUM = c.ETA_NUM and a.RSA_NUM = c.RSA_NUM
%end;
%else %if &AN = 15 %then %do;
  left join ORAVUE.T_MCO&AN.GV11G c on a.ETA_NUM = c.ETA_NUM and a.RSA_NUM = c.RSA_NUM
%end;
%else %do;

/*Ajout de l'année N+1 et N-1*/

%macro More_years (an1);

%if "an1"<2015%then %do;
	%if "&an1"="&anp1" %then %do;	
	%let suffix_code = %eval(67 + (20&an1. - 2011));
    %let suffix = %sysfunc(byte(&suffix_code));
left join ORAVUE.T_MCO&anp1.GV11&suffix b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
	%end;
	%else %do;	
	%let suffix_code = %eval(67 + (20&an1. - 2010));
    %let suffix = %sysfunc(byte(&suffix_code));
left join ORAVUE.T_MCO&anp1.GV11&suffix b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
	%end; 	
%end;
/* S lection pour 2015 */
%if"an1"=2015 %then %do;
	%if "&an1"="&anp1" %then %do;	
		left join ORAVUE.T_MCO&anp1.GV20&anp1. b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
	%end;
	%else %do;	
		left join ORAVUE.T_MCO&an1.GV11G b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM	 
	%end;
%end;
/* Sélection pour 2015 */
%if "an1">2015 %then %do;
%if "&an1"="&anp1" %then %do;	
		left join ORAVUE.T_MCO&anp1.GV20&anp1. b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
	%end;
	%else %do;	
		left join ORAVUE.T_MCO&an1.GV20&an1. b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM	 
	%end;
%end;

  left join ORAVUE.T_MCO&AN.GV20&AN. c on a.ETA_NUM = c.ETA_NUM and a.RSA_NUM = c.RSA_NUM
%end;
	where
    /* Etablissements */
    &COND_ETAB_NONAP and &COND_SEJ_NONB
    /* Chainage */
    and &COND_CHAINAGE_OK
    /* Diagnostics valides et pas soins palliatifs */
    and &COND_DGN_PAL_OK and &COND_NO_SOIN_PALL
    /* Typologie séjours */
    and &COND_NO_SEANCE and &COND_NO_OBS_TRANS
    and &COND_NO_AMBU_SPEC and &COND_NO_CATARACTE
    /* Patients */
    and &COND_ADULT and &COND_DOMICILE_FR
    /* Mode sortie et entrée */
    and &COND_SORTIE_VIE and &COND_NO_TRANSFERT
    and &COND_ENT_DOM
    and substr(c.GHM_NUM,3,1) in ('C', 'K') /* Example for COND_CHIR */
    /* Ensure all macro variables reference the correct table aliases */
  ;
quit;

/* N+1 si demandé */

  %if %upcase(&AJOUT_NPLUS1)=OUI %then %do;
    %let ANP1 = %eval(&AN+1);

    proc sql;
      create table SASDATA1.RHOSP_&ANP1 as
      select 
        c.NIR_ANO_17 as num_ano,
        datepart(c.EXE_SOI_DTD) as dt_entree format=date9.
      from ORAVUE.T_MCO&ANP1.C c
      where month(datepart(c.EXE_SOI_DTD)) in (1,2)  /* suffisant pour fenètre 30 j */
      ;
    quit;
  %end;

/* Après Normalisaiton : détection des séjours indexes*/

proc sql;
create table Index as 
select 
from SASDATA1.RHOSP_&AN. 

quit;


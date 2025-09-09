proc options option=encoding;

run;

/********************************************************************************************************/

/* librairie */
%let Fichiers=%sysget(HOME)/sasdata;

%let annee = 2012; /* Param tre   indiquer : ann e sur laquelle on veut calculer les taux RH30 */
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

/************************************************************************************************/
/* ETAPE 0 : Cr ation d'une base de diagnostiques en N, N-1 et N+1 au m me format que le SNDS */
/************************************************************************************************/

%macro Diag_SNDS(an);
proc sql;
create table MCO&an.bd_diag as
select ETA_NUM, RSA_NUM, DGN_PAL as DIAG, '1' as TYP_DIAG
from ORAVUE.T_MCO&an.B
where ETA_NUM not in &AP.
and not missing(DGN_PAL)
and DGN_PAL not in ('RSSABS', 'XXXX')

union all

select b.ETA_NUM, b.RSA_NUM, b.DGN_PAL as DIAG, '3' as TYP_DIAG
from ORAVUE.T_MCO&an.B a
left join ORAVUE.T_MCO&an.UM b
on a.ETA_NUM = b.ETA_NUM
and a.RSA_NUM = b.RSA_NUM
and input(a.SEQ_RUM,2.) ne b.UM_ORD_NUM
where b.ETA_NUM not in &AP.
and not missing(b.DGN_PAL)
and b.DGN_PAL not in ('XXXX')
and not missing(b.UM_ORD_NUM)

union all

select ETA_NUM, RSA_NUM, DGN_REL as DIAG, '2' as TYP_DIAG
from ORAVUE.T_MCO&an.B
where ETA_NUM not in &AP.
and not missing(DGN_REL)
and DGN_REL ne 'XXXX'

union all

select b.ETA_NUM, b.RSA_NUM, b.DGN_REL as DIAG, '4' as TYP_DIAG
from ORAVUE.T_MCO&an.B a
left join ORAVUE.T_MCO&an.UM b
on a.ETA_NUM = b.ETA_NUM
and a.RSA_NUM = b.RSA_NUM
and input(a.SEQ_RUM,2.) ne b.UM_ORD_NUM
where b.ETA_NUM not in &AP.
and not missing(b.DGN_REL)
and b.DGN_REL not in ('XXXX')
and not missing(b.UM_ORD_NUM)

union all

select ETA_NUM, RSA_NUM, ASS_DGN as DIAG, '5' as TYP_DIAG
from ORAVUE.T_MCO&an.D
where ETA_NUM not in &AP.
and not missing(ASS_DGN)
and ASS_DGN not in ('XXXX')
;
quit;
%mend;

%Diag_SNDS(&an);
%Diag_SNDS(&anp1);

/***************************************************************************************/
/* ETAPE 1) Cr ation d'une base du 01/01/N-1 au 28/02/N+1,   partir des bases snds */
/***************************************************************************************/

%macro fichier_an (an1);

/* s lection des soins palliatifs en DA, DP_UM et DR_UM */
proc sql;
create table diag_20&an1. as
select distinct ETA_NUM, RSA_NUM , 1 as DA_SoinsPall
from MCO&an1.bd_diag
where ETA_NUM not in &AP. and typ_diag > '2' and substr(upcase(diag),1,4)= "Z515";
quit;

proc sql;
create table fixe_20&an1. as
select a.ETA_NUM, a.RSA_NUM, ENT_MOD, SOR_MOD, SEJ_NBJ, a.SOR_ANN, a.SOR_MOI, a.COD_SEX, BDI_COD, AGE_ANN,
b.NIR_ANO_17, b.EXE_SOI_DTD, b.EXE_SOI_DTF
from ORAVUE.T_MCO&an1.B a left join ORAVUE.T_MCO&an1.C b
on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
where /* suppression des doublons*/
a.ETA_NUM not in &AP.
/* exclusion des s jours de type B */
and (SEJ_TYP^="B" or missing(SEJ_TYP))
/* s lection des s jours bien chain s */
and NIR_RET = '0' and NAI_RET = '0' and SEX_RET = '0' and SEJ_RET = '0' and FHO_RET = '0'
and PMS_RET = '0' /*and DAT_RET = '0' and COH_NAI_RET= '0' and COH_SEX_RET= '0'
/* Sur N+1, s lection des mois de janvier f vrier N+1 */
%if "&an1"="&anp1" %then %do; and a.SOR_MOI in ("01","02") %end;
;

/*R cup ration/normalisation du ghm en vN+1 pour les donn es N et N+1 */
create table rsa_chain_20&an1. as
select a.*, b.GHM_NUM, d.DA_SoinsPall
from fixe_20&an1 a

%if "an1"<2015 %then %do;
%if "&an1"="&anp1" %then %do;
%let suffix_code = %eval(67 + (20&an1. - 2011));
%let suffix = %sysfunc(byte(&suffix_code));
%let table = ORAVUE.T_MCO&an1.GV11&suffix;
left join ORAVUE.T_MCO&anp1.GV11&suffix b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
%end;
%else %do;
%let suffix_code = %eval(67 + (20&an1. - 2010));
%let suffix = %sysfunc(byte(&suffix_code));
%let table = ORAVUE.T_MCO&an1.GV11&suffix;
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
/* S lection apr s 2015 */
%if "an1">2015 %then %do;
%if "&an1"="&anp1" %then %do;
left join ORAVUE.T_MCO&anp1.GV20&anp1. b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
%end;
%else %do;
left join ORAVUE.T_MCO&an1.GV20&an1. b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
%end;
%end;
left join diag_20&an1. d on a.ETA_NUM = d.ETA_NUM and a.RSA_NUM = d.RSA_NUM
/* Exclusion des s ances et des s jours group s en erreurs */
where substr(b.GHM_NUM,1,2) not in ("28","90");
quit;

data rsa_chain_20&an1;
set rsa_chain_20&an1;
if DA_SoinsPall=. then DA_SoinsPall=0;
run;
%mend;

%fichier_an(&an);
%fichier_an(&anp1);


data rsa_&an._&anp1;
set rsa_chain_20&an rsa_chain_20&anp1;
run;

/* rsa_N_N+1 => Base avec tous les RSA regroup s en &ver du 01/01/N-1 au 28/02/N+1, n cessaire
au calcul des RH 30 (hors s ances, CMD 90, sejours de type B et s jours non correctement chain s) */


/*************************************************************************************************/
/* ETAPE 2) Exclusion des s jours et patients ne respectant pas les crit res d'inclusion */
/*************************************************************************************************/


data rsa_&an._&anp1._;
set rsa_&an._&anp1;
/* suppression des s jours d'obst trique et de transplantation*/
if substr(GHM_NUM,1,2) in ("14","15","27") then delete;
/* suppression des s ances en hospitalisation et des s jours cataracte*/
if substr(GHM_NUM,1,5) in ('11K02','17M05','17M06','17K04','17K05','17K06','17K08','17K09','23M09','02C05','02C12') then delete;
/* Cr ation de variables */
if SOR_MOD = "9" then DECES = 1; else DECES = 0;
CMD = substr(GHM_NUM,1,2);
NIV = substr(GHM_NUM,6,1);
RACINEV11=substr(GHM_NUM,1,5);
length libelle_CAS hospit $30.;
if substr (GHM_NUM,3,1)='C' and SEJ_NBJ>0 then do; code_CAS='CH';libelle_CAS='Chirurgie non ambulatoire';end;
else if substr (GHM_NUM,3,1)='C' and SEJ_NBJ=0 then do; code_CAS='CJ';libelle_CAS='Chirurgie ambulatoire';end;
else if substr (GHM_NUM,3,1)='K' then do; code_CAS='PI';libelle_CAS='Interventionnel';end;
else if substr (GHM_NUM,3,1) in('Z','M') and SEJ_NBJ=0 then do; code_CAS='X0';libelle_CAS='M decine ambulatoire';end;
else if substr (GHM_NUM,3,1) in('Z','M') and SEJ_NBJ>0 then do; code_CAS='XH';libelle_CAS='M decine non ambulatoire'; end;
if SEJ_NBJ=0 then hospit="Ambulatoire"; else hospit="Hospitalisation compl te";
run;

/*Exclusion de patients, ancienne  tape 3*/

proc sql;
create table rsa_&an._&anp1._x as
select NIR_ANO_17, RSA_NUM, ETA_NUM, EXE_SOI_DTD, EXE_SOI_DTF, ENT_MOD, SOR_MOD,SOR_ANN,SOR_MOI, GHM_NUM,
count(*) as nbhospittot&annee
from rsa_&an._&anp1._
where SOR_ANN="&annee"
/* keep only patients NOT matching exclusions */
and not (DA_SoinsPall=1 or GHM_NUM in ("23Z02Z","23Z02T")) /* no palliative */
and not (substr(BDI_COD,1,2) in ('99','9E','9G','9H','9J')) /* no foreign/TOM */
and not (substr(BDI_COD,3,3)='999') /* no code geo = 999 */
and not (AGE_ANN<18) /* no minors */
group by NIR_ANO_17;
quit;


/*****************************************************/
/*Etape 3 : cr ation des d lais entre s jours */
/*****************************************************/
/* Cr ation d'une variable d lai2 = d lai en nb de jours entre 2 hospit sur toute la base du 01/01/N-1 au 28/02/N+1 */
proc sort data=rsa_&an._&anp1._x;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF SOR_MOD;
/* tri sur ano_datefin et mode de sortie n cessaire qd il y a 2 hospit avec m me date entree et sortie */
run;

data rsa_&an._&anp1._a (drop =d);
set rsa_&an._&anp1._x ;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF SOR_MOD SOR_ANN SOR_MOI;

/*The RETAIN statement causes a variable that is created in the DATA step to retain its value from the current observation into the next observation.
The variable is not set to missing at the beginning of each iteration of the DATA step. RETAIN is a declarative statement, not an executable statement*/

retain d;
if first.NIR_ANO_17=1 then d=.;
else delai2=(EXE_SOI_DTD-d)/86400; /* delai2 = delai entre 2 hospit sur tous les s jours N-1   fev N+1 */
d=EXE_SOI_DTF;
/* je fige un numero d'ordre pour les tris d'apr s, pour que ce soit tjs tri  de la m me fa on (pb si 2 s jours de 0 jour le m me jour avec m me mode de sortie) */
retain numordre;
if _N_=1 then numordre=0;
numordre=numordre+1;
run;

/* Cr ation de la variable delai_suiv qui indique le delai de l'enregistrement suivant
(exemple : le delai entre sej1 et sej2 sur la ligne de sej1) */

data rsa_&an._&anp1._b;
set rsa_&an._&anp1._a;
by NIR_ANO_17 ;
set rsa_&an._&anp1._a ( firstobs = 2 keep = delai2 SOR_ANN rename = (delai2 = delai_suiv SOR_ANN=SOR_ANN_suiv) );
delai_suiv = ifn( last.NIR_ANO_17, (.), delai_suiv );
SOR_ANN_suiv = ifn( last.NIR_ANO_17, (.), SOR_ANN_suiv );
run;

/* R cup ration du dernier enregistrement qui a  t  supprim  */
data dern_enr; set rsa_&an._&anp1._a end=eof; if eof; run;

data rsa_&an._&anp1._c; set rsa_&an._&anp1._b dern_enr; run;

/************************************************************/
/* ETAPE 4) Rehospitalisations d but N+1 li es   ann e N */
/************************************************************/

/* 1. Extraire seulement les rehosp de janv-f vr N+1 */
data rsa_Rehospt_Debut_&anneep1;
set rsa_&an._&anp1._c;
where SOR_ANN="&anneep1" and SOR_MOI in ('01','02');
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;

retain nbhospit&anneep1;
if first.NIR_ANO_17 then nbhospit&anneep1=0;
nbhospit&anneep1+1;

/* inclure uniquement si s jour N+1 suit un s jour N ?30j */
if first.NIR_ANO_17 and 1 <= delai2 <= 30 then inclAnSuiv=1;
else inclAnSuiv=0;
run;

/* 2. Fusionner avec base N, garder seulement les rehosp valides */
data rsa_supp_&annee._c;
set rsa_&an._&anp1._c
rsa_Rehospt_Debut_&anneep1(where=(inclAnSuiv=1));
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;

/* Num ro du dernier s jour en N */
NbDernHospit&annee = lag(nbhospit&annee);
NbDernHospitTot&annee = lag(nbhospittot&annee);

/* Exclure rehosp N+1 si s jour pr c dent  tait avant ann e N */
if nbhospit&anneep1=1 and NbDernHospit&annee=. then delete;
run;

data Bdd_rh30_Base_1ercouple_&annee;
set rsa_supp_&annee._c (drop=inclAnSuiv NbDernHospit&annee NbDernHospitTot&annee);
run;

/* A partir de la base ci-dessus, cr ation de 2 bases :
- 1 base contenant tous les s jours index potentiels
- 1 base contenant toutes les r hospitalisation potentielles */

/******************************************************************/
/* ETAPE 5) Cr ation d'une base des s jours index potentiels */
/******************************************************************/

proc sql;
create table Bdd_sej_index_potentiel_&annee as
select *, 1 as Sej_Index_Pot
from Bdd_rh30_Base_1ercouple_&annee
where
(delai2 is null or delai2 > 30) /* suppression des s jours dans 30 jours pr c dents */
and (delai_suiv not in (0) or delai_suiv is null or delai_suiv > -1) /* suppression des transferts */
and SOR_MOD not in ("0","6","7") /* transferts */
and (index(GHM_NUM, 'C') = 0 and GHM_NUM not in ("03K02", "05K14", "11K07", "12K06", "09Z02", "14Z08", "23Z03")) /* suppression chirurgies */
and SOR_MOD ne "9" /* mort en sortie */
and ENT_MOD = "8" /* admission depuis domicile */
and SOR_ANN ne "&anneep1"; /* suppression s jours N+1 */
quit;


/******************************************************************************/
/* ETAPE 6) Cr ation d'une base des s jours de r hospitalisation potentielles */
/******************************************************************************/

proc sql;
create table Bdd_rh30_tot_rehosp_&annee._ as
select *, 1 as Rehosp_Pot
from Bdd_rh30_Base_1ercouple_&annee
where NIR_ANO_17 in (select distinct NIR_ANO_17 from Bdd_sej_index_potentiel_&annee);
quit;

/* Application des autres crit res d'exclusion des r hospit */
proc sort data=Bdd_rh30_tot_rehosp_&annee._; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

data Bdd_sej_rehosp_potentiel_&annee;
set Bdd_rh30_tot_rehosp_&annee._;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;

/* Suppression des 1er s jour de l'ann e de chaque patient (le 1er sejour de l'ann e ne peut  tre qu'une hospit index et pas une rehospit)
=>  a englobe aussi les 1er s jours termin s en N qui sont en fait des r hospitalisations dans les 30 jours d'un s jour termin  en N-1 */
if first.NIR_ANO_17 then delete;
/* Suppression des s jours avec mode d'entr e diff rent de domicile (ne peuvent pas  tre des r hospit) */
if ENT_MOD not in ("8") then delete;
run;


/*********************************************************************************************************/
/* ETAPE 7) Concat nation verticale des tables d'hospit index potentiels et de rehospit potentielles */
/*********************************************************************************************************/

data Bdd_Global_&annee;
set Bdd_sej_index_potentiel_&annee
Bdd_sej_rehosp_potentiel_&annee;
run;

/* Suppression des doublons */
proc sort data=Bdd_Global_&annee nodupkey; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

/* j'ajoute les variables s jour index potentiels O/N et rehospit potentiel O/N */

proc sql;
create table Bdd_Global_&annee._a as
select a.*,b.Sej_Index_Pot,c.Rehosp_Pot
from Bdd_Global_&annee a
left join Bdd_sej_index_potentiel_&annee b
on a.NIR_ANO_17=b.NIR_ANO_17 and a.ETA_NUM=b.ETA_NUM and a.RSA_NUM=b.RSA_NUM
left join Bdd_sej_rehosp_potentiel_&annee c
on a.NIR_ANO_17=c.NIR_ANO_17 and a.ETA_NUM=c.ETA_NUM and a.RSA_NUM=c.RSA_NUM;
quit;


/*****************************************************************************************************/
/* ETAPE 8) Identification des s jours index suivis d'une RH30 et d'une RH30 suite   un s jour index */
/*****************************************************************************************************/

proc sort data=Bdd_Global_&annee._a; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

/* recalcul des d lai entre les s jours inclus */
data Bdd_Global_&annee._b (drop =d);
set Bdd_Global_&annee._a ;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;
retain d;
if first.NIR_ANO_17=1 then d=.;
else delai3=(EXE_SOI_DTD-d)/86400;
d=EXE_SOI_DTF;
run;

/* Ciblage des rehospit   30 jours et de leur s jour index */
proc sort data=Bdd_Global_&annee._b; by NIR_ANO_17 descending numordre; run;

data Bdd_Global_&annee._c;
set Bdd_Global_&annee._b ;
/* Cr ation d'une variable qui indique si rehospit   30j */
if 0<delai3<31 and Rehosp_Pot=1 then RH30j=1;

/* Cr ation d'une variable qui indique si s jour index d'une rehospit   30j */
RH30j_suiv=lag(RH30j);
if RH30j_suiv=1 and Sej_Index_Pot=1 then Index_RH30j=1; /* si Index_RH30j=1 alors s jour index d'une RH30 */
run;

proc sort data=Bdd_Global_&annee._c; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

data Bdd_Global_&annee._d;
set Bdd_Global_&annee._c ;
/* Cr ation d'une variable qui indique si s jour = RH30 avec sej index possible */
index_prec=lag(Index_RH30j);
if RH30j=1 and index_prec=1 then RH30j_fin=1; /* si RH30j_fin=1 alors RH30 suite   un s jour index */
run;

/* cr ation de compteurs de s jours chronologique,
pour trouver le sej index et la premi re rehospitalisation */

data Bdd_Global_&annee._e ;
set Bdd_Global_&annee._d ;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;
retain cpt;
if first.NIR_ANO_17 then cpt=0;
if Index_RH30j=1 or RH30j_fin=1 then do; cpt=cpt+1; couple=cpt; end;
/* si le s jour est un s jour index d'une RH30 ou une RH30 suite   un s jour index,
la variable couple s'incr mente de 1*/
if Index_RH30j=. and RH30j_fin=. then couple=0;
/* si le s jour n'est pas un s jour index d'une RH30 ni une RH30 suite   un s jour index,
la variable couple est nulle */
drop cpt;
run;

/* Somme par patient les valeurs de couple */
proc sql;
create table BDD_Global_&annee._e_Pat as select NIR_ANO_17,
sum(couple) as couple_p from BDD_Global_&annee._e group by 1;
/* et j'inclus cette somme dans ma base globale */
create table BDD_Global_&annee._f as select a.*, b.* from
BDD_Global_&annee._e a left join BDD_Global_&annee._e_Pat b on a.NIR_ANO_17=b.NIR_ANO_17;
quit;

/* conserver uniquement les s jours du premier couple */
data Bdd_Global_&annee._g;
set Bdd_Global_&annee._f;
/* pour les patients avec rehospit   30j,
conservation du 1er couple d'hospit uniquement (hospit index,rehospit) */
if couple_p>=3 and couple not in (1,2) then delete;
/* pour les patients sans rehospit   30j,
suppression des s jours qui ne sont pas des s jours index potentiels */
if couple_p=0 and Sej_Index_Pot^='1' then delete;
run;

proc sort data=Bdd_Global_&annee._g; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

data Bdd_Global_&annee._h;
set Bdd_Global_&annee._g;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;
if couple_p=0 then do;
/* pour les patients sans rehospit   30j */
if first.NIR_ANO_17^=1 then delete;
/* seule la 1er hospit est conserv e = uniquement le 1er sejour index potentiel... */
end;
run;

/* Sauvegarde de la table finale */
data Bdd_rh30_meth1ercouple_&annee;
set Bdd_Global_&annee._h;
drop DA_SoinsPall annee_suiv nbhospit&annee nbhospittot&annee nbhospit&anneep1 supprEntPasDom suppr30jprec Sej_Index_Pot Rehosp_Pot RH30j RH30j_suiv
index_prec couple_p delai2 delai_suiv Index_RH30j RH30j_fin;
run;

proc sort data=Bdd_rh30_meth1ercouple_&annee; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

/*%end;
%mend;

%rehosp();*/

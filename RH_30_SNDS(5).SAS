/********************************************************************************************************/

/* librairie    */
%let Fichiers=%sysget(HOME)/sasdata;
	
%let annee  = 2012; 	/* Paramètre à indiquer : année sur laquelle on veut calculer les taux RH30 */ 		
%let anneem1 = %eval(&annee-1 );   
%let anneep1 = %eval(&annee+1 ); 
%let an  = %substr(&annee,3,2); 		
%let anm1 = %substr(&anneem1,3,2); 
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
/* ETAPE 0 : Création d'une base de diagnostiques en N, N-1 et N+1 au même format que le SPDS	*/
/************************************************************************************************/

%macro Diag_SNDS(an);
	proc sql;
	create table MCO&an._DP_1   as
	select 	ETA_NUM, RSA_NUM, DGN_PAL,'1' as TYP_DIAG
	from ORAVUE.T_MCO&an.B
	where ETA_NUM not in &AP. and not missing(DGN_PAL) and DGN_PAL not in  ('RSSABS' 'XXXX');

	*proc sql;
	create table MCO&an._DP_3   as
	select 	b.ETA_NUM, b.RSA_NUM, b.DGN_PAL, '3' as TYP_DIAG
	from ORAVUE.T_MCO&an.B a left join ORAVUE.T_MCO&an.UM b
		on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM 
		and input(a.SEQ_RUM,2.) ne b.UM_ORD_NUM
	where b.ETA_NUM not in &AP. and not missing(b.DGN_PAL) and b.DGN_PAL not in  ('XXXX') 
		and not missing(b.UM_ORD_NUM);
	*quit;

	*proc sql;
	create table MCO&an._DR_2   as
	select 	ETA_NUM, RSA_NUM, DGN_REL,'2' as TYP_DIAG
	from ORAVUE.T_MCO&an.B
	where ETA_NUM not in &AP. and not missing(DGN_REL) and DGN_REL ne 'XXXX';

	*proc sql;
	create table MCO&an._DR_4   as
	select 	b.ETA_NUM, b.RSA_NUM, b.DGN_REL, '4' as TYP_DIAG
	from ORAVUE.T_MCO&an.B a left join ORAVUE.T_MCO&an.UM b
		on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM 
		and input(a.SEQ_RUM,2.) ne b.UM_ORD_NUM
	where b.ETA_NUM not in &AP. and not missing(b.DGN_REL) and b.DGN_REL not in ('XXXX') 
		and not missing(b.UM_ORD_NUM);

	*proc sql;
	create table MCO&an._DA (rename=(ASS_DGN = DIAG))  as
	select 	ETA_NUM, RSA_NUM, ASS_DGN,'5' as TYP_DIAG
	from ORAVUE.T_MCO&an.D
	where ETA_NUM not in &AP. and not missing(ASS_DGN) and ASS_DGN not in  ('xxxx');
	quit;

	data MCO&an.bd_diag;
	set MCO&an._DP_1 (rename=(DGN_PAL = DIAG)) 
	MCO&an._DR_2 (rename=(DGN_REL = DIAG)) 
	MCO&an._DP_3 (rename=(DGN_PAL = DIAG))
	MCO&an._DR_4 (rename=(DGN_REL = DIAG)) 
	MCO&an._DA;
	run;
%mend;

%Diag_SNDS(&an);
%Diag_SNDS(&anm1);
%Diag_SNDS(&anp1);

/***********************************************************************************/
/* ETAPE 1)	Création d'une base du 01/01/N-1 au 28/02/N+1, à partir des bases snds */
/***********************************************************************************/

%macro fichier_an (an1);

/* sélection des soins palliatifs en DA, DP_UM et DR_UM */
	proc sql;
		create table diag_20&an1. as 
		select distinct ETA_NUM, RSA_NUM , 1 as DA_SoinsPall
		from MCO&an1.bd_diag
		where ETA_NUM not in &AP. and typ_diag > '2' and substr(upcase(diag),1,4)= "Z515";
	quit;

proc sql;
	create table fixe_20&an1. as 
	select 	a.ETA_NUM, a.RSA_NUM, ENT_MOD, SOR_MOD, SEJ_NBJ, a.SOR_ANN, a.SOR_MOI, a.COD_SEX, BDI_COD, AGE_ANN, 
			b.NIR_ANO_17, b.EXE_SOI_DTD, b.EXE_SOI_DTF 
	from ORAVUE.T_MCO&an1.B a left join ORAVUE.T_MCO&an1.C b
	on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
	where 	/* suppression des doublons*/
			a.ETA_NUM not in &AP. 
			/* exclusion des séjours de type B : presta inter-établissement*/
			and (SEJ_TYP^="B" or missing(SEJ_TYP))
			/* sélection des séjours bien chainés */
			and NIR_RET = '0' and NAI_RET = '0' and SEX_RET = '0' and SEJ_RET = '0' and FHO_RET = '0' 
			and PMS_RET = '0' /*and DAT_RET = '0' and COH_NAI_RET= '0' and COH_SEX_RET= '0'
			/* Sur N+1, sélection des mois de janvier février N+1 */
			%if "&an1"="&anp1" %then %do; and a.SOR_MOI in ("01","02") %end;
	;
	
	/*Récupération/normalisation du ghm en vN+1 pour les données N et N+1 et vN pour les données N-1*/ 
	create table rsa_chain_20&an1. as 
	select 	a.*, b.GHM_NUM, d.DA_SoinsPall
	from fixe_20&an1 a
	
	%if "an1"<2015%then %do;
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
	/* Sélection pour 2015 */
	%if"an1"=2015 %then %do;
		%if "&an1"="&anp1" %then %do;	
			left join ORAVUE.T_MCO&anp1.GV20&anp1. b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
		%end;
		%else %do;	
			left join ORAVUE.T_MCO&an1.GV11G b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM	 
		%end;
	%end;
	/* Sélection après 2015 */
	%if "an1">2015 %then %do;
	%if "&an1"="&anp1" %then %do;	
			left join ORAVUE.T_MCO&anp1.GV20&anp1. b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM
		%end;
		%else %do;	
			left join ORAVUE.T_MCO&an1.GV20&an1. b on a.ETA_NUM = b.ETA_NUM and a.RSA_NUM = b.RSA_NUM	 
		%end;
	%end;
	left join diag_20&an1. d on a.ETA_NUM = d.ETA_NUM and a.RSA_NUM = d.RSA_NUM
	/* Exclusion des séances et des séjours groupés en erreurs */
	where substr(b.GHM_NUM,1,2) not in ("28","90");
quit;
		
	data rsa_chain_20&an1; 
		set rsa_chain_20&an1;
		if DA_SoinsPall=. then DA_SoinsPall=0;
	run;
%mend;

%fichier_an(&anm1);
%fichier_an(&an); 
%fichier_an(&anp1);


data rsa_&anm1._&anp1;
set rsa_chain_20&anm1 rsa_chain_20&an rsa_chain_20&anp1; 
run;

/* rsa_N-1_N+1 => Base avec tous les RSA regroupés en &ver du 01/01/N-1 au 28/02/N+1, nécessaire 
au calcul des RH 30 (hors séances, CMD 90, sejours de type B et séjours non correctement chainés) */


/*************************************************************************************/
/* ETAPE 2) 	Exclusion des séjours ne respectant pas les critères d'inclusion 	 */
/*************************************************************************************/

data rsa_&anm1._&anp1._;
set rsa_&anm1._&anp1;
/* suppression des séjours d'obstétrique et de transplantation*/
if substr(GHM_NUM,1,2) in ("14","15","27") then delete;
/* suppression des séances en hospitalisation*/
if substr(GHM_NUM,1,5) in ('11K02','17M05','17M06','17K04','17K05','17K06','17K08','17K09','23M09') then delete;
/* suppression des séjours cataracte*/
if substr(GHM_NUM,1,5) in ('02C05','02C12') then delete;
/* Création de variables Décès, CMD, gravité, racine */
if SOR_MOD = "9" then DECES = 1; else DECES = 0;
PONDER = 1;
CMD = substr(GHM_NUM,1,2);
NIV = substr(GHM_NUM,6,1);
RACINEV11=substr(GHM_NUM,1,5);
length libelle_CAS  hospit $30.;
/*Variables de type de soins*/ 
if substr (GHM_NUM,3,1)='C' and SEJ_NBJ>0 then do; code_CAS='CH';libelle_CAS='Chirurgie non ambulatoire';end;
else if substr (GHM_NUM,3,1)='C' and SEJ_NBJ=0 then do; code_CAS='CJ';libelle_CAS='Chirurgie ambulatoire';end;
else if substr (GHM_NUM,3,1)='K' then do; code_CAS='PI';libelle_CAS='Interventionnel';end;
else if substr (GHM_NUM,3,1) in('Z','M') and SEJ_NBJ=0 then do; code_CAS='X0';libelle_CAS='Médecine ambulatoire';end;
else if substr (GHM_NUM,3,1) in('Z','M') and SEJ_NBJ>0 then do; code_CAS='XH';libelle_CAS='Médecine non ambulatoire'; end;
if SEJ_NBJ=0 then hospit="Ambulatoire"; else hospit="Hospitalisation complète";
run;

/* Création d'une variable délai2 = délai en nb de jours entre 2 hospit sur toute la base du 01/01/N-1 au 28/02/N+1 */
proc sort data=rsa_&anm1._&anp1._; 
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF SOR_MOD; 
/* tri sur ano_datefin et mode de sortie nécessaire qd il y a 2 hospit avec même date entree et sortie */
run;

data rsa_&anm1._&anp1._a (drop =d);
set  rsa_&anm1._&anp1._ ;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF SOR_MOD; 
retain d;
if first.NIR_ANO_17=1 then d=.;
else delai2=(EXE_SOI_DTD-d)/86400; /* delai2 = delai entre 2 hospit sur tous les séjours N-1 à fev N+1 */	 
d=EXE_SOI_DTF;
/* je fige un numero d'ordre pour les tris d'après, pour que ce soit tjs trié de la même façon (pb si 2 séjours de 0 jour le même jour avec même mode de sortie) */
retain numordre;	
if _N_=1 then numordre=0;
numordre=numordre+1;
run;

/* Création de la variable delai_suiv qui indique le delai de l'enregistrement suivant 
(exemple : le delai entre sej1 et sej2 sur la ligne de sej1) */
data rsa_&anm1._&anp1._b;
set rsa_&anm1._&anp1._a;
by NIR_ANO_17 ; 
set rsa_&anm1._&anp1._a ( firstobs = 2 keep = delai2 SOR_ANN rename = (delai2 = delai_suiv SOR_ANN=SOR_ANN_suiv) );
delai_suiv = ifn(  last.NIR_ANO_17, (.), delai_suiv );
SOR_ANN_suiv = ifn(  last.NIR_ANO_17, (.), SOR_ANN_suiv );
run;

/* Récupération du dernier enregistrement qui a été supprimé */
data dern_enr; set rsa_&anm1._&anp1._a end=eof; if eof; run;

data rsa_&anm1._&anp1._c; set rsa_&anm1._&anp1._b dern_enr; run;	


/******************************************************************************************************/
/* ETAPE 3) 	Repérage des patients à exclure (exclusions patient)								  */
/******************************************************************************************************/

data rsa_excl_&annee;
set rsa_&anm1._&anp1._c(where=(SOR_ANN="&annee"));
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;

retain nbhospit&annee;
if first.NIR_ANO_17 then nbhospit&annee=0;
nbhospit&annee=nbhospit&annee+1;

/*EXCLUSION DES PATIENTS*/

/* Exclusion : patient ayant eu au moins un séjours de soins palliatifs qu’il soit : 
codé en diagnostic principal  ou en diagnostic associé  */
if DA_SoinsPall=1 or GHM_NUM in ("23Z02Z","23Z02T") then supprSoinPall=1;
else  supprSoinPall=0;

/*Exclusion= patient avec un séjour avec code géo étranger ou = à un TOM */
if  substr(BDI_COD,1,2) in ('99','9E','9G','9H','9J') then supprPasFce=1;
else supprPasFce=0;

/*Exclusion= patient avec un séjour avec code géo non précis (terminant par 999) */
if  substr(BDI_COD,3,3)='999' then supprCodeGeoNP=1;
else supprCodeGeoNP=0;

/*Exclusion= patient avec un séjour avec un age <18 ans */
if  AGE_ANN<18 then supprMineur=1;
else supprMineur=0;

run;

/* Ciblage des patients concernés par les exclusions patient */

proc sql;
	create table pat_excl_&annee as
	select NIR_ANO_17, sum(supprSoinPall) as supprSoinPallP, sum(supprPasFce) as supprPasFceP,sum(supprCodeGeoNP) as supprCodeGeoNPP,
	sum(supprMineur) as supprMineurP, sum(ponder) as nbhospittot&annee
	from rsa_excl_&annee
	group by 1;

	create table rsa_supp_&annee as
	select a.*,b.*
	from rsa_excl_&annee a left join pat_excl_&annee b
	on a.NIR_ANO_17=b.NIR_ANO_17;
quit;

/*************************************************************************************************************/
/* ETAPE 4)		Sélection des séjours de réhospitalisation possible sur début N+1 suite à une hospit de N	 */
/*************************************************************************************************************/

/* Sélection des rehospit de début N+1 d'une hospit terminée en N pour les intégrer dans la base de l'année N */

data rsa_Rehospt_Debut_&anneep1;
set rsa_&anm1._&anp1._c (where=( SOR_ANN="&anneep1" and SOR_MOI in ('01','02'))); /* sélection des mois de janv fev N+1 (même groupage) */
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;

retain nbhospit&anneep1;
if first.NIR_ANO_17 then nbhospit&anneep1=0;
nbhospit&anneep1=nbhospit&anneep1+1;

/* Inclusion - patient dont le premier séjour aurait lieu début janvier N+1 et serai précédé d’un séjour en décembre N dans un délai 30j;*/
if first.NIR_ANO_17 and delai2>=1 and  delai2<=30 then inclAnSuiv=1;
else inclAnSuiv=0;

/* mais exclusion des séjours de soins palliatifs, des séjours avec un mode d'entrée différent de domicile, 
des séjours avec code géo étranger, TOM et non précis et exclusion des séjours des moins de 18 ans */ 
if DA_SoinsPall=1 or GHM_NUM in ("23Z02Z","23Z02T") 
or ENT_MOD not in ("8") 
or substr(BDI_COD,1,2) in ('99','9E','9G','9H','9J')
or substr(BDI_COD,3,3)='999'
or AGE_ANN <18
then inclAnSuiv=0; 
run;           

/* Intégration des rehospitalisations N+1 suite à une hospitalisation terminée en N */

data rsa_supp_&annee._b;
set rsa_supp_&annee rsa_Rehospt_Debut_&anneep1(where=(inclAnSuiv=1));
run; 

proc sort data=rsa_supp_&annee._b;  by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;	
 
data rsa_supp_&annee._c;
set rsa_supp_&annee._b;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;
/* pour les réhospit debut N+1, recherche du numéro de la dernière hospit N */ 
NbDernHospit&annee=ifn(NIR_ANO_17=lag(NIR_ANO_17),lag(nbhospit&annee),"");
/* Récupération du nb total d'hospit en N */
NbDernHospitTot&annee=ifn(NIR_ANO_17=lag(NIR_ANO_17),lag(nbhospittot&annee),"");
if nbhospit&anneep1=1 then do;
	nbhospit&annee=NbDernHospit&annee+1;
	supprSoinPallP=0; supprPasFceP=0; supprCodeGeoNPP=0; supprMineurP=0; 
end;
if nbhospit&anneep1=. then NbDernHospit&annee=.;	/* dernière hospit de l'année N */
if nbhospit&anneep1=1 and NbDernHospit&annee=. then delete;  
/* suppression des réhospit qui se termine en N+1 suite à une 1ere hospit antérieur à l'année N (en N-1) */
run;   

/* recalcul des sommes par patient*/

proc sql;
create table pat_annee_suiv_&annee as
	select NIR_ANO_17, sum(supprSoinPallP) as supprSoinPallP_fin,
	sum(supprPasFceP) as supprPasFceP_fin,sum(supprCodeGeoNPP) as supprCodeGeoNPP_fin,sum(supprMineurP) as supprMineurP_fin
	from rsa_supp_&annee._c
	group by 1;
create table rsa_supp_&annee._d as
	select a.*,b.*
	from rsa_supp_&annee._c  a left join pat_annee_suiv_&annee b
	on a.NIR_ANO_17=b.NIR_ANO_17;
quit;

/* je sauvegarde (temporairement cette base) */

data Bdd_rh30_Base_1ercouple_&annee;
set rsa_supp_&annee._d (drop=inclAnSuiv NbDernHospit&annee NbDernHospitTot&annee supprPasFceP supprCodeGeoNPP supprMineurP supprSoinPallP
supprPasFce supprCodeGeoNP supprMineur supprSoinPall);
run;


/*  La table RH30.Bdd_rh30_Base_1ercouple_&annee exclut :
 - les séjours mal chainés
 - les séjours de type B 
 - les séances et séjours en erreur (CMD 28 et 90)
 - les séjours d'obstétrique et de transplantation (CMD 14 15 27)
 - les séances en hospitalisation ('11K02','17M05','17M06','17K04','17K05','17K06','17K08','17K09','23M09')
 - les séjours pour cataracte (02C05 et 02C12)*/
																						 
/* Cette table contient les variables d'EXCLUSION DES PATIENTS  : 
 - supprSoinPallP_fin : patient ayant eu au moins un séjours de soins palliatifs qu’il soit : codé en diagnostic principal ou en diagnostic associé  
 - supprPasFceP_fin : patient avec un séjour avec code géo étranger
 - supprCodeGeoNPP_fin : patient avec un séjour avec code géo non précis (terminant par 999) 
 - supprMineurP_fin : patient avec un séjour avec un age <18 ans 	  */

/* Cette table inclut les séjours terminés en janvier fevrier N+1 :
 - qui sont précédés d’un séjour de N dans un délai 30j;
 - qui ne soint pas des séjours de soins palliatifs 
 - mode d'entrée = domicile, 
 - qui ont un code géo ni étranger ni TOM et ni imprécis 
 - avec age >= 18 ans */ 

/* A partir de la base ci-dessus, création de 2 bases :
 - 1 base contenant tous les séjours index potentiels
 - 1 base contenant toutes les réhospitalisation potentielles */

/*********************************************************************************/
/* ETAPE 5)		Création d'une base des séjours index potentiels 				 */
/*********************************************************************************/

data Bdd_rh30_tot_index_&annee; 
set Bdd_rh30_Base_1ercouple_&annee;
/* Suppression des patients ayant eu au moins un séjours de soins palliatifs qu’il soit 
codé en diagnostic principal ou en diagnostic associé	
 => supprSoinPallP_fin>=1 */
/* Suppression des séjours qui sont suivis d’un transfert (ne peuvent pas être des séjours index) */
if ((delai_suiv=0 or (delai_suiv<=-1 and delai_suiv ne .)) or SOR_MOD  in ("0","6","7"))then supprTrans=1;
else supprTrans=0;
/*Je garde les séjours de type chirurgie*/
if index(GHM_NUM, 'C')>1 or GHM_NUM in ("03K02", "05K14", "11K07", "12K06", "09Z02", "14Z08", "23Z03") then supprCHir=1;
else supprCHir=0;
/* Suppression des séjours terminés par un décès (ne peuvent pas être des séjours index) */
if SOR_MOD="9" then supprDC=1;
else supprDC=0;
/* je supprime les patients avec un séjour avec code géo étranger ou = à un TOM
=> supprPasFceP_fin>=1 */
/* je supprime les patients avec un séjour avec code géo non précis (terminant par 999) 
=> supprCodeGeoNPP_fin>=1 */
/* je supprime les patients ayant au moins un séjour avec un age <18 ans 
=> supprMineurP_fin>=1 */
/*  Suppression des séjours avec un mode d'entrée différent de domicile */ *TODO : suppression à faire remonter puisq'elle est aussi présente en exclusion des réhospit;
if ENT_MOD not in ("8") then supprEntPasDom=1;	
else supprEntPasDom=0;
/* Suppression des séjours qui sont précés d'une hospitalisation dans les 30 jours qui précèdent */
if delai2^=. and delai2<=30 then suppr30jprec=1;
else suppr30jprec=0;
/* Suppression des séjours de N+1 (ne peuvent pas être des séjours index) */
if SOR_ANN="&anneep1" then supprAnSuiv=1;
else supprAnSuiv=0;
run;	

/* Base avec les séjours index potentiels */
data Bdd_sej_index_potentiel_&annee; 
set Bdd_rh30_tot_index_&annee;
if supprSoinPallP_fin>=1 or supprCHir=0 or supprTrans=1 or supprDC=1 or supprPasFceP_fin>=1 or supprCodeGeoNPP_fin>=1 or supprMineurP_fin>=1 or supprAnSuiv=1 or 
supprEntPasDom=1 or suppr30jprec=1 then delete;
Sej_Index_Pot='1';
run;


/***************************************************************************************/
/* ETAPE 6) 	Création d'une base des séjours de réhospitalisation potentiels 		*/
/***************************************************************************************/

/* Exclusion des patients n'ayant pas de séjours index potentiel (s'ils n'ont pas de séjour index possible, ils ne peuvent pas avoir une RH)*/
proc sql;
create table Bdd_rh30_tot_rehosp_&annee._ as select * from Bdd_rh30_Base_1ercouple_&annee
where NIR_ANO_17 in (select distinct NIR_ANO_17 from Bdd_sej_index_potentiel_&annee);
quit;

/* Application des autres critères d'exclusion des réhospit */
proc sort data=Bdd_rh30_tot_rehosp_&annee._;  by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;	

data Bdd_rh30_tot_rehosp_&annee; 
set Bdd_rh30_tot_rehosp_&annee._;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;
/* je supprime les patients ayant eu au moins un séjour de soins palliatifs qu’il soit : codé en diagnostic principal ou en diagnostic associé	
 => supprSoinPallP_fin>=1 */
/* je supprime les patients avec un séjour avec code géo étranger
=> supprPasFceP_fin>=1 */
/* je supprime les patients avec un séjour avec code géo non précis (terminant par 999) 
=> supprCodeGeoNPP_fin>=1 */
/* je supprime les patients ayant au moins un séjour avec un age <18 ans 
=> supprMineurP_fin>=1 */

/* Suppression des 1er séjour de l'année de chaque patient (le 1er sejour de l'année ne peut être qu'une hospit index et pas une rehospit) 
	=> ça englobe aussi les 1er séjours terminés en N qui sont en fait des réhospitalisations dans les 30 jours d'un séjour terminé en N-1 */
if first.NIR_ANO_17 then supprPremHosp=1;
else supprPremHosp=0;
/* Suppression des séjours avec mode d'entrée différent de domicile (ne peuvent pas être des réhospit) */
if ENT_MOD not in ("8") then supprPasDom=1;	 
else supprPasDom=0;
run;	 

/* Base avec les séjours de rehospit potentiels */
data Bdd_sej_rehosp_potentiel_&annee; 
set Bdd_rh30_tot_rehosp_&annee;
if supprSoinPallP_fin>=1 or supprPasFceP_fin>=1 or supprCodeGeoNPP_fin>=1 or supprMineurP_fin>=1 or supprPremHosp=1 or supprPasDom=1 then delete;
Rehosp_Pot='1';
run;


/*********************************************************************************************************/
/* ETAPE 7)		Concaténation verticale des tables d'hospit index potentiels et de rehospit potentielles */
/*********************************************************************************************************/

data Bdd_Global_&annee;
set Bdd_sej_index_potentiel_&annee(drop=supprSoinPallP_fin supprTrans supprDC supprPasFceP_fin supprCodeGeoNPP_fin supprMineurP_fin supprAnSuiv Sej_Index_Pot) 
Bdd_sej_rehosp_potentiel_&annee(drop=supprSoinPallP_fin supprPasFceP_fin supprCodeGeoNPP_fin supprMineurP_fin supprPremHosp supprPasDom Rehosp_Pot); 
run;

/* Suppression des doublons */
proc sort data=Bdd_Global_&annee nodupkey; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

/* j'ajoute les variables Sejour index potebntiel O/N et rehospit potentiel O/N */

proc sql;
create table Bdd_Global_&annee._a as
select a.*,b.Sej_Index_Pot,c.Rehosp_Pot
from Bdd_Global_&annee a 	left join Bdd_sej_index_potentiel_&annee b
								on a.NIR_ANO_17=b.NIR_ANO_17 and a.ETA_NUM=b.ETA_NUM and a.RSA_NUM=b.RSA_NUM
				  			left join Bdd_sej_rehosp_potentiel_&annee c
								on a.NIR_ANO_17=c.NIR_ANO_17 and a.ETA_NUM=c.ETA_NUM  and a.RSA_NUM=c.RSA_NUM;
quit;


/*********************************************************************************************************/
/* ETAPE 8)		Identification des séjours index suivis d'une RH30 et d'une RH30 suite à un séjour index */
/*********************************************************************************************************/

proc sort data=Bdd_Global_&annee._a; by  NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

/* recalcul des délai entre les séjours inclus */
data Bdd_Global_&annee._b (drop =d);
set  Bdd_Global_&annee._a ;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;
retain d;
if first.NIR_ANO_17=1 then d=.;
else delai3=(EXE_SOI_DTD-d)/86400;	 
d=EXE_SOI_DTF;
run; 

/* Ciblage des rehospit à 30 jours et de leur séjour index */
proc sort data=Bdd_Global_&annee._b; by NIR_ANO_17 descending numordre; run;

data Bdd_Global_&annee._c;
set  Bdd_Global_&annee._b ;
/* Création d'une variable qui indique si rehospit à 30j */
if 0<delai3<31 and Rehosp_Pot=1 then RH30j=1;

/* Création d'une variable qui indique si séjour index d'une rehospit à 30j */
RH30j_suiv=lag(RH30j);
if RH30j_suiv=1 and	 Sej_Index_Pot=1 then Index_RH30j=1; /* si Index_RH30j=1 alors séjour index d'une RH30 */
run;

proc sort data=Bdd_Global_&annee._c; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

data Bdd_Global_&annee._d;
set  Bdd_Global_&annee._c ;
/* Création d'une variable qui indique si séjour = RH30 avec sej index possible */
index_prec=lag(Index_RH30j);
if RH30j=1 and	index_prec=1 then RH30j_fin=1; /* si RH30j_fin=1 alors RH30 suite à un séjour index */
run;

/* création de compteurs de séjours chronologique, 
	pour trouver le sej index et la première rehospitalisation */

data Bdd_Global_&annee._e ;
set  Bdd_Global_&annee._d ;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;
retain cpt;
if first.NIR_ANO_17 then cpt=0;
if Index_RH30j=1 or RH30j_fin=1 then do; cpt=cpt+1; couple=cpt; end; 
/* si le séjour est un séjour index d'une RH30 ou une RH30 suite à un séjour index, 
la variable couple s'incrémente de 1*/
if Index_RH30j=. and RH30j_fin=. then couple=0; 
/* si le séjour n'est pas un séjour index d'une RH30 ni une RH30 suite à un séjour index,
la variable couple est nulle */
drop  cpt;
run; 

/* Somme par patient les valeurs de couple */
proc sql;
create table BDD_Global_&annee._e_Pat as select NIR_ANO_17, 
sum(couple) as couple_p from BDD_Global_&annee._e group by 1;
/* et j'inclus cette somme dans ma base globale */
create table BDD_Global_&annee._f as select a.*, b.* from 
BDD_Global_&annee._e a left join BDD_Global_&annee._e_Pat b on a.NIR_ANO_17=b.NIR_ANO_17;
quit;


/* conserver uniquement les séjours du premier couple */
data Bdd_Global_&annee._g;
set Bdd_Global_&annee._f;
/* pour les patients avec rehospit à 30j, 
conservation du 1er couple d'hospit uniquement (hospit index,rehospit) */
if couple_p>=3 and couple not in (1,2) then delete;
/* pour les patients sans rehospit à 30j, 
suppression des séjours qui ne sont pas des séjours index potentiels */ 
if couple_p=0 and Sej_Index_Pot^='1' then delete;  
run;

proc sort data=Bdd_Global_&annee._g; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

data Bdd_Global_&annee._h;
set Bdd_Global_&annee._g;
by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre;
if couple_p=0 then do; 
/* pour les patients sans rehospit à 30j */
if first.NIR_ANO_17^=1 then delete;	 
/* seule la 1er hospit est conservée = uniquement le 1er sejour index potentiel... */
end;
run;


/* Sauvegarde de la table finale */
data Bdd_rh30_meth1ercouple_&annee;
set Bdd_Global_&annee._h;
drop DA_SoinsPall annee_suiv nbhospit&annee nbhospittot&annee nbhospit&anneep1 supprEntPasDom suppr30jprec Sej_Index_Pot Rehosp_Pot RH30j RH30j_suiv 
index_prec couple_p delai2 delai_suiv Index_RH30j RH30j_fin;
run;


proc sort data=Bdd_rh30_meth1ercouple_&annee; by NIR_ANO_17 EXE_SOI_DTD EXE_SOI_DTF numordre; run;

%end;
%mend;

%rehosp();






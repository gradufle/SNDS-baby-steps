%macro Volume_an(start=13, end=24);

%let AP = ('130780521', '130783236', '130783293', '130784234', '130804297','130784259',   '600100101', '750041543', '750100018', '750100042', '750100075', '750100083', '750100091', '750100109', '750100125', '750100166', '750100208', '750100216', '750100232', '750100273', '750100299', '750801441', '750803447', '750803454', '910100015', '910100023', '920100013', '920100021', '920100039', '920100047', '920100054', '920100062', '930100011', '930100037', '930100045', '940100027', '940100035', '940100043', '940100050', '940100068', '950100016', '690783154', '690784137', '690784152', '690784178', '690787478', '830100558');
%do an = &start %to &end;

%_eg_conditional_dropds(ORAUSER.Liste_Actes_chir_&an.);

/*	**********Choix Actes Chirurgie Totale OR APHP ********** */
PROC SQL;
   CREATE TABLE ORAUSER.Liste_Actes_chir_&an. AS 
   SELECT t1.GRG_GHM, 
          t1.RSA_NUM,  
          t2.ETA_NUM_GEO, 
          t4.EXE_SOI_DTD, 
          t4.EXE_SOI_DTF
      FROM ORAVUE.T_MCO&an.B t1, ORAVUE.T_MCO&an.E t3, 
		   ORAVUE.T_MCO&an.UM t2, ORAVUE.T_MCO&an.C t4
      WHERE (
			t1.GRG_GHM CONTAINS "03K02" OR 
			t1.GRG_GHM CONTAINS "05K14" OR 
			t1.GRG_GHM CONTAINS "11K07" OR 
			t1.GRG_GHM CONTAINS "12K06" OR 
			t1.GRG_GHM CONTAINS "09Z02" OR 
			t1.GRG_GHM CONTAINS "14Z08" OR 
			t1.GRG_GHM CONTAINS "23Z03" OR
			t1.GRG_GHM CONTAINS 'C')
			AND(t1.ETA_NUM = t3.ETA_NUM AND t1.ETA_NUM = t2.ETA_NUM 
		   	AND t1.RSA_NUM = t2.RSA_NUM AND t1.ETA_NUM = t4.ETA_NUM 
           	AND t1.RSA_NUM = t4.RSA_NUM)
			AND t2.ETA_NUM_GEO NOT IN &AP.;
QUIT;

/*	********** Volumes d'actes en Chirurgie Total OR APHP ********** */

PROC SQL;
   CREATE TABLE ORAUSER.VOLUME_ACTES_CHIR_&an. AS 
   SELECT DISTINCT /* COUNT_of_GRG_GHM */
                     (COUNT(t1.RSA_NUM)) AS Volume_actes_chir, 
          t1.ETA_NUM,
		  2000 + &an AS Year
      FROM ORAUSER.LISTE_ACTES_CHIR_&an. t1
      GROUP BY t1.ETA_NUM;
QUIT;

/* ********** Table unique ********** */

%if &an. = &start %then %do;
	%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_CHIR);
	proc sql;
		create 	table ORAUSER.VOLUME_ACTES_CHIR as
		select * from ORAUSER.VOLUME_ACTES_CHIR_&an.;
	quit;
%end;

%else %do;
    proc sql;
	    insert into ORAUSER.VOLUME_ACTES_CHIR
	    select * from ORAUSER.VOLUME_ACTES_CHIR_&an.;
	quit;
%end;

%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_CHIR_&an.);

/* ********** Volume par types d'actes CCAM et etablissement ********** */

%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_CHIR_BYA_&an.);

PROC SQL;
   CREATE TABLE ORAUSER.VOLUME_ACTES_CHIR_BYA_&an. AS 
   SELECT t3.CDC_ACT, /* Nb_act_chir_BYA */
            (COUNT(t3.RSA_NUM)) AS Volume_actes_chir_BYA,
			t1.ETA_NUM,
			2000 + &an AS Year
      FROM ORAUSER.Liste_Actes_chir_&an. t1, ORAVUE.T_MCO&an.A t3
      WHERE (t1.ETA_NUM = t3.ETA_NUM AND t1.RSA_NUM = t3.RSA_NUM)
      GROUP BY t3.CDC_ACT, t1.ETA_NUM;
QUIT;

/* ********** Table unique Volumes actes chir CCAM ********** */

%if &an. = &start %then %do;
	%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_CHIR_BYA);
	proc sql;
		create table ORAUSER.VOLUME_ACTES_CHIR_BYA as
		select * from ORAUSER.VOLUME_ACTES_CHIR_BYA_&an.;
	quit;
%end;

%else %do;
    proc sql;
	    insert into ORAUSER.VOLUME_ACTES_CHIR_BYA
	    select * from ORAUSER.VOLUME_ACTES_CHIR_BYA_&an.;
	quit;
%end;

/* ********** Valeurs par types d'actes CCAM ********** */

%_eg_conditional_dropds(ORAUSER.NB_ACTES_CHIR_BYA_&an.);

PROC SQL;
   CREATE TABLE ORAUSER.NB_ACTES_CHIR_BYA_&an. AS 
   SELECT DISTINCT t3.CDC_ACT, /* Nb_act_chir_BYA */
            (COUNT(t3.CDC_ACT)) AS Nb_act_chir_BYA,
			t3.CDC_ACT,
			2000 + &an AS Year
      FROM ORAUSER.Liste_Actes_chir_&an. t1, ORAVUE.T_MCO&an.A t3
      WHERE (t1.ETA_NUM = t3.ETA_NUM AND t1.RSA_NUM = t3.RSA_NUM)
      GROUP BY t3.CDC_ACT;
QUIT;

/* ********** Table unique Nb actes chir CCAM ********** */

%if &an. = &start %then %do;
	%_eg_conditional_dropds(ORAUSER.NB_ACTES_CHIR_BYA);
	proc sql;
		create table ORAUSER.NB_ACTES_CHIR_BYA as
		select * from ORAUSER.NB_ACTES_CHIR_BYA_&an.;
	quit;
%end;

%else %do;
    proc sql;
	    insert into ORAUSER.NB_ACTES_CHIR_BYA
	    select * from ORAUSER.NB_ACTES_CHIR_BYA_&an.;
	quit;
%end;

/*	**********Choix Actes Chirurgie Ambulatoires********** 	*/

%_eg_conditional_dropds(ORAUSER.Liste_Actes_Ambu_chir_&an.);

PROC SQL;
   CREATE TABLE ORAUSER.Liste_Actes_Ambu_chir_&an. AS 
   SELECT t1.GRG_GHM, 
          t1.RSA_NUM,  
          t2.ETA_NUM_GEO, 
          t4.EXE_SOI_DTD, 
          t4.EXE_SOI_DTF
      FROM ORAVUE.T_MCO&an.B t1, ORAVUE.T_MCO&an.E t3, 
		   ORAVUE.T_MCO&an.UM t2, ORAVUE.T_MCO&an.C t4
      WHERE (
			t1.GRG_GHM CONTAINS "03K02" OR 
			t1.GRG_GHM CONTAINS "05K14" OR 
			t1.GRG_GHM CONTAINS "11K07" OR 
			t1.GRG_GHM CONTAINS "12K06" OR 
			t1.GRG_GHM CONTAINS "09Z02" OR 
			t1.GRG_GHM CONTAINS "14Z08" OR 
			t1.GRG_GHM CONTAINS "23Z03" OR
			t1.GRG_GHM CONTAINS 'C')
			AND(t1.ETA_NUM = t3.ETA_NUM AND t1.ETA_NUM = t2.ETA_NUM 
		   	AND t1.RSA_NUM = t2.RSA_NUM AND t1.ETA_NUM = t4.ETA_NUM 
           	AND t1.RSA_NUM = t4.RSA_NUM) AND t4.EXE_SOI_DTD = t4.EXE_SOI_DTF
			AND t2.ETA_NUM_GEO NOT IN &AP.;
QUIT;

/*	********** Volumes d'actes en Chirurgie Ambulatoire ********** */

PROC SQL;
   CREATE TABLE ORAUSER.VOLUME_ACTES_AMBU_CHIR_&an. AS 
   SELECT DISTINCT /* COUNT_of_GRG_GHM */
                     (COUNT(t1.RSA_NUM)) AS Volume_ambu_chir, 
          t1.ETA_NUM,
		  2000 + &an AS Year
      FROM ORAUSER.LISTE_ACTES_AMBU_CHIR_&an. t1
      GROUP BY t1.ETA_NUM;
QUIT;


/* ********** Table Unique ********** */

%if &an. = &start %then %do;
	%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_AMBU_CHIR);
	proc sql;
		create table ORAUSER.VOLUME_ACTES_AMBU_CHIR as
		select * from ORAUSER.VOLUME_ACTES_AMBU_CHIR_&an.;
	quit;
%end;

%else %do;
    proc sql;
	    insert into ORAUSER.VOLUME_ACTES_AMBU_CHIR
	    select * from ORAUSER.VOLUME_ACTES_AMBU_CHIR_&an.;
	quit;
%end;

%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_AMBU_CHIR_&an.);

/* ********** Volume ambu par types d'actes CCAM et etablissement ********** */

%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA_&an.);

PROC SQL;
   CREATE TABLE ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA_&an. AS 
   SELECT t3.CDC_ACT, /* Nb_act_chir_BYA */
            (COUNT(t3.RSA_NUM)) AS Volume_actes_ambu_chir_BYA,
			t1.ETA_NUM,
			2000 + &an AS Year
      FROM ORAUSER.Liste_Actes_ambu_chir_&an. t1, ORAVUE.T_MCO&an.A t3
      WHERE (t1.ETA_NUM = t3.ETA_NUM AND t1.RSA_NUM = t3.RSA_NUM)
      GROUP BY t3.CDC_ACT, t1.ETA_NUM;
QUIT;


/* ********** Table unique Volumes actes chir CCAM ********** */

%if &an. = &start %then %do;
	%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA);
	proc sql;
		create table ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA as
		select * from ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA_&an.;
	quit;
%end;

%else %do;
    proc sql;
	    insert into ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA
	    select * from ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA_&an.;
	quit;
%end;


/* **** NB actes Amublatoire par type CCAM **** */

%_eg_conditional_dropds(ORAUSER.Nb_ACTES_AMBUL_ByA_&an.);

PROC SQL;
   CREATE TABLE ORAUSER.Nb_ACTES_AMBUL_ByA_&an. AS 
   SELECT DISTINCT /* Nb_actes_Ambu_BYA */
                     (COUNT(t1.CDC_ACT)) AS Nb_actes_Ambu_BYA, 
          t1.CDC_ACT, 
		  2000 + &an AS Year
      FROM ORAVUE.T_MCO&an.A t1, ORAUSER.Liste_Actes_Ambu_chir_&an. t2
      WHERE (t1.RSA_NUM = t2.RSA_NUM AND t1.ETA_NUM = t2.ETA_NUM)
      GROUP BY t1.CDC_ACT;
QUIT;

/* ********** Table Unique Nb actes chir Ambu National********** */

%if &an. = &start %then %do;
	%_eg_conditional_dropds(ORAUSER.Nb_ACTES_AMBUL_ByA);
	proc sql;
		create table ORAUSER.Nb_ACTES_AMBUL_ByA as
		select * 
		from ORAUSER.Nb_ACTES_AMBUL_ByA_&an.;
	quit;
%end;

%else %do;
    proc sql;
	    insert into ORAUSER.Nb_ACTES_AMBUL_ByA
	    select * from ORAUSER.Nb_ACTES_AMBUL_ByA_&an.;
	quit;
%end;

%_eg_conditional_dropds(ORAUSER.Nb_ACTES_AMBUL_ByA_&an.);
%_eg_conditional_dropds(ORAUSER.Nb_ACTES_CHIR_ByA_&an.);
%_eg_conditional_dropds(ORAUSER.LISTE_ACTES_AMBU_CHIR_&an.);
%_eg_conditional_dropds(ORAUSER.LISTE_ACTES_CHIR_&an.);
%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA&an.);
%_eg_conditional_dropds(ORAUSER.VOLUME_ACTES_CHIR_BYA&an.);





%end;
%mend;

%Volume_an();
























/* ********** Taux de chirugie ambulatoire ********** */

%_eg_conditional_dropds(ORAUSER.Taux_Ambu_Nat_ByA);

PROC SQL;
   CREATE TABLE ORAUSER.Taux_Ambu_Nat_ByA AS 
   SELECT t1.CDC_ACT, 
          t1.Nb_actes_Ambu_BYA, 
          t2.Nb_act_chir_BYA,
		  t1.YEAR,
          /* TauxAmbuNat_BYA */
            (t1.Nb_actes_Ambu_BYA / t2.Nb_act_chir_BYA) AS Taux_Ambu_Nat_BYA
  	 		FROM ORAUSER.NB_ACTES_CHIR_BYA t2
         	INNER JOIN ORAUSER.NB_ACTES_AMBUL_BYA t1 
		 	ON (t2.CDC_ACT = t1.CDC_ACT) AND (t2.YEAR = t1.YEAR);
QUIT;

/* ******* Indice d'organisation par acte CCAM ******* */

%_eg_conditional_dropds(ORAUSER.Indice_orga_bya);

PROC SQL;
	Create table ORAUSER.Indice_orga_BYA AS 
	select * ,
	t3.Volume_actes_ambu_chir_bya,
	t3.Volume_actes_ambu_chir_bya/(t1.Volume_actes_chir_bya*t2.TAUX_AMBU_NAT_BYA) AS Indice_orga_bya 
	from ORAUSER.Volume_actes_chir_bya t1	
	INNER JOIN ORAUSER.TAUX_AMBU_NAT_BYA t2 
		   ON (t2.CDC_ACT = t1.CDC_ACT) AND (t1.Year = t2.Year)
	INNER JOIN ORAUSER.VOLUME_ACTES_AMBU_CHIR_BYA t3 
		   ON (t3.CDC_ACT = t1.CDC_ACT) AND (t1.Year = t3.Year) AND (t1.ETA_NUM = t3.ETA_NUM);
QUIT;

/* ******** Indice d'organisation par établissement ******** */

%_eg_conditional_dropds(ORAUSER.Indice_orga);

PROC SQL;
	Create table ORAUSER.Indice_orga AS 
	select t1.ETA_NUM,
	t1.CDC_ACT,
	t1.Year,
	t2.VOLUME_ACTES_CHIR,
	t3.VOLUME_AMBU_CHIR,
	t1.Volume_actes_ambu_chir_bya,
	t1.Indice_orga_bya
	from ORAUSER.Indice_orga_bya t1, ORAUSER.VOLUME_ACTES_CHIR t2, ORAUSER.VOLUME_ACTES_AMBU_CHIR t3
	Where t1.ETA_NUM=t2.ETA_NUM AND t1.Year=t2.Year and  t1.ETA_NUM=t3.ETA_NUM AND t1.Year=t3.Year
	;
QUIT;


%_eg_conditional_dropds(ORAUSER.Indice_orga2);


PROC SQL;
	Create table ORAUSER.INDICE_ORGA2 AS
	select t1.ETA_NUM,
	t1.year,
	SUM(t1.VOLUME_ACTES_CHIR) AS VOLUME_ACTES_CHIR,
	SUM(t1.VOLUME_AMBU_CHIR) AS VOLUME_AMBU_CHIR, 
	SUM(t1.Indice_orga_bya * t1.Volume_actes_ambu_chir_bya/t1.volume_actes_chir) as indice_IO
	from ORAUSER.indice_orga t1
	group by t1.ETA_NUM, t1.Year
	;
QUIT;


/* ******** Volume ambulatoir innovant ******** */

/*  tout acte CCAM dont le taux moyen national de chirurgie ambulatoire est inférieur à 20%,
avec un nombre d’actes CCAM ambulatoires supérieur à 10. */

%_eg_conditional_dropds(ORAUSER.ACTES_AMBU_INNO);

Proc SQL;
	Create table ORAUSER.ACTES_AMBU_INNO AS
	select 
	t1.CDC_ACT,
	t1.year,
	(t1.taux_ambu_nat_bya<0.2) as is_inno,
	(t1.NB_act_chir_bya>10) as is_numerous10
	from ORAUSER.TAUX_AMBU_NAT_BYA t1;
Quit;

%_eg_conditional_dropds(ORAUSER.VOL_AMBU_INNO);

Proc SQL;
	Create Table ORAUSER.VOL_AMBU_INNO AS
	select 
	t1.year, 
	t1.ETA_NUM,
	SUM(t1.Volume_actes_ambu_chir_bya*t2.IS_INNO*t2.IS_NUMEROUS10) as volume_inno
	from Orauser.ACTES_AMBU_INNO t2, Orauser.INDICE_ORGA t1
	where t1.CDC_ACT=t2.CDC_ACT and t1.year=t2.year
	group by t1.ETA_NUM, t1.year ;
Quit;

/* *********** IPCA ************* */

%_eg_conditional_dropds(ORAUSER.BASE_IPCA);

Proc Sql ; 
	Create table Orauser.base_ipca AS
	Select 
	t1.year,
	t1.ETA_NUM,
	t1.volume_inno,
	t2.VOLUME_AMBU_CHIR,
	t2.indice_IO,	
	t2.VOLUME_ACTES_CHIR
	from ORAUSER.VOL_AMBU_INNO t1, ORAUSER.INDICE_ORGA2 t2
	where t1.year=t2.year and t1.ETA_NUM=t2.ETA_NUM 
	group by t1.ETA_NUM, t1.year;
Quit;


/* Calcul des rangs (en pourcentage) en utilisant les percentils 
	pour normaliser entre 0 et 100 */

%_eg_conditional_dropds(ORAUSER.base_ipca_sorted);

proc sort data=ORAUSER.base_ipca out=ORAUSER.base_ipca_sorted;
    by year;
run;

%_eg_conditional_dropds(ORAUSER.ranked_ipca1);

proc rank data=ORAUSER.base_ipca_sorted out=ORAUSER.ranked_ipca1 ties=mean groups=100;
	by year;
    var  indice_IO ;
    ranks  rank_IO ;
run;

%_eg_conditional_dropds(ORAUSER.ranked_ipca2);

proc rank data=ORAUSER.ranked_ipca1 out=ORAUSER.ranked_ipca2 ties=mean groups=100;
	by year;
    var volume_ambu_chir;
    ranks rank_ambu;
run;

%_eg_conditional_dropds(ORAUSER.ranked_ipca);

proc rank data=ORAUSER.ranked_ipca2 DESCENDING out=ORAUSER.ranked_ipca ties=mean groups=100;
	by year;
    var  volume_inno;
    ranks rank_inno;
run;


%_eg_conditional_dropds(ORAUSER.IPCA);

data Orauser.IPCA;
  set ORAUSER.ranked_ipca;
  IPCA = 0.5 * rank_ambu + 0.3 * rank_IO + 0.2 * rank_inno;
run;

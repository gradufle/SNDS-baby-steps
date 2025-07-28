/********************************** */
/* Calcul du score de Charlson
********************* */
********************************;
* Récupération des soins - Codes CIM10;
* Dans les ALD;
%extract_ALD_CIM(
tbl_out = reperage_CIM10_ALD_Charlson,
tbl_codes = codes_CIM_Charlson3,
tbl_patients = corresp_id_patient
);
* Dans les hospitalisations;
%extract_CIM10_PMSI(
annee_deb = &annee_1N.,
annee_fin = &annee_N.,
HAD_DP = 0,
HAD_DAS = 0,
HAD_MPP = 0,
HAD_MPA = 0,
MCO_DP = 1,
MCO_DR = 1,
MCO_DAS = 1,
MCO_DP_UM = 1,
MCO_DR_UM = 1,
SSR_FP = 0,
SSR_MPP = 0,
SSR_AE = 0,
SSR_DAS = 0,
tbl_out = reperage_CIM10_PMSI_Charlson,
tbl_codes = codes_CIM_Charlson3,
tbl_patients = corresp_id_patient
);

data reperage_cim10_charlson ;
length type $12.;
set reperage_CIM10_ALD_Charlson (in = a)
reperage_CIM10_PMSI_Charlson (in = b);
if b then
source = "PMSI";
if a then
source = "ALD";
run;
proc delete data = reperage_CIM10_ALD_Charlson reperage_CIM10_PMSI_Charlson;
run; quit;
*
******************************************************************************************************
************************************;
* À partir des données repérées, sélectionner les lignes pour lesquels les soins ont lieu dans l année précédant le 1er janvier de
l année
de repérage;
* Codes CIM 10;
data reperage_CIM10_Charlson;
set reperage_CIM10_Charlson (where = ((source = "PMSI" and
intnx("year", "01JAN&Annee_N."d, -1, 'same') <= date_debut <= "01JAN&Annee_N."d
or intnx("year", "01JAN&Annee_N."d, -1, 'same') <= date_fin <= "01JAN&Annee_N."d
or date_debut < intnx("year", "01JAN&Annee_N."d, -1, 'same') and date_fin > "01JAN&Annee_N."d) or (source =
"ALD" and
date_debut <= intnx("year", "31DEC&Annee_N."d, -1, 'same') and (date_fin = "01JAN1600"d or date_fin is null
or date_fin >= intnx("year", "01JAN&Annee_N."d, -1, 'same')))));
run;

*
******************************************************************************************************
************************************;
* Pour les médicaments, on regarde les nombres de délivrances;
* Pour les traitements de la démence, il faut au moins 3 délivrances;
proc sql;
CREATE TABLE Charlson_DCIR_demence AS
SELECT *
FROM reperage_ATC_Charlson
WHERE reperage = 5
GROUP BY BEN_IDT_ANO
HAVING COUNT(DISTINCT date_debut) >= 3;
quit;
* Pour les traitements de reperage pulmonaire chronique, il faut au moins 3 délivrances;
proc sql;
CREATE TABLE Charlson_DCIR_pulmonaire AS
SELECT *
FROM reperage_ATC_Charlson
WHERE reperage = 6
GROUP BY BEN_IDT_ANO
HAVING COUNT(DISTINCT date_debut) >= 3;

quit;
* Pour les traitements de diabète sans complication, il faut au moins 3 délivrances (ou 2 en cas de grand conditionnement);
proc sql;
CREATE TABLE Charlson_DCIR_diabete2 AS
SELECT *
FROM reperage_ATC_Charlson
WHERE PHA_CND_TOP = "GC" AND reperage = 10
GROUP BY BEN_IDT_ANO
HAVING COUNT(DISTINCT date_debut) >= 2;
CREATE TABLE Charlson_DCIR_diabete3 AS
SELECT *
FROM reperage_ATC_Charlson
WHERE PHA_CND_TOP NE "GC" AND reperage = 10
GROUP BY BEN_IDT_ANO
HAVING COUNT(DISTINCT date_debut) >= 3;
quit;

*
******************************************************************************************************
************************************;
* Création de la table contenant le score de Charlson;
data reperages_Charlson;
set reperage_CCAM_Charlson (keep = BEN_IDT_ANO reperage)
reperage_CIM10_Charlson (keep = BEN_IDT_ANO reperage)
reperage_GHM_Charlson (keep = BEN_IDT_ANO reperage)
Charlson_DCIR_demence (keep = BEN_IDT_ANO reperage)
Charlson_DCIR_pulmonaire (keep = BEN_IDT_ANO reperage)
Charlson_DCIR_diabete2 (keep = BEN_IDT_ANO reperage)
Charlson_DCIR_diabete3 (keep = BEN_IDT_ANO reperage);
run;
* On récupère 1 info unique par patient;
proc sort data = reperages_Charlson nodupkey;
by BEN_IDT_ANO reperage;
run;
proc delete data = reperage_CCAM_Charlson reperage_CIM10_Charlson reperage_GHM_Charlson
Charlson_DCIR_demence
Charlson_DCIR_pulmonaire Charlson_DCIR_diabete2 Charlson_DCIR_diabete3;
run; quit;
*
******************************************************************************************************
************************************;
* Correction des reperages;
* Les patients repérés pour Diabète sans complication + Patho cérébrovasculaire ou patho rénale modérée ou sévère ou infarctus du
myocarde;
* => Diabète avec complication;
data patients_Diabete_sans;
set reperages_Charlson;
where reperage = 10;
run;
data patients_complications;
set reperages_Charlson;
where reperage in (1, 4, 12);
run;
proc sql;
DELETE FROM reperages_Charlson
WHERE BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_Diabete_sans)
AND BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_complications)
AND reperage = 10;

INSERT INTO reperages_Charlson
SELECT BEN_IDT_ANO,
FROM patients_Diabete_sans
WHERE BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_complications);
quit;
proc delete data = patients_Diabete_sans patients_complications;
run; quit;
* Les patients repérés pour Diabète sans complication et Diabète avec complication => Diabète avec complication;
data patients_Diabete_sans;
set reperages_Charlson;
where reperage = 10;
run;
data patients_Diabete_avec;
set reperages_Charlson;
where reperage = 13;
run;
proc sql;
DELETE FROM reperages_Charlson
WHERE BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_Diabete_sans)
AND BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_Diabete_avec)
AND reperage = 10;
quit;
proc delete data = patients_Diabete_sans patients_Diabete_avec;
run; quit;
* Les patients repérés pour Cancer et Pathologie métastatique => Pathologie métastatique;
data patients_Cancer;
set reperages_Charlson;
where reperage = 14;
run;
data patients_Metastatique;
set reperages_Charlson;
where reperage = 16;
run;
proc sql;
DELETE FROM reperages_Charlson
WHERE BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_Cancer)
AND BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_Metastatique)
AND reperage = 14;
quit;
proc delete data = patients_Cancer patients_Metastatique;
run; quit;
* Les patients repérés pour Pathologie hépatique légère et Pathologie hépatique modérée ou sévère => Pathologie hépatique modérée
ou sévère;
data patients_hepatique_leg;
set reperages_Charlson;
where reperage = 9;
run;
data patients_hepatique_sev;
set reperages_Charlson;
where reperage = 15;
run;
proc sql;

DELETE FROM reperages_Charlson
WHERE BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_hepatique_leg)
AND BEN_IDT_ANO IN (SELECT BEN_IDT_ANO FROM patients_hepatique_sev)
AND reperage = 9;
quit;
proc delete data = patients_hepatique_leg patients_hepatique_sev;
run; quit;


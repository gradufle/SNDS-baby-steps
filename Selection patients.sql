/*
******************************************************************************************************
************************************ */
/*
*/
/* Sélection des patients
*/
/*
*/
/*
******************************************************************************************************
************************************ */
*
******************************************************************************************************
************************************;
* On récupère tous les BEN_NIR_PSA de chaque patient;
proc sql undo_policy = none;
%connectora;
CREATE TABLE patients_IR_BEN_R AS
SELECT * FROM CONNECTION TO ORACLE (
SELECT DISTINCT
BEN_IDT_ANO,
BEN_NIR_PSA,
BEN_RNG_GEM
FROM IR_BEN_R
);
disconnect from oracle;
quit;
%suppr_table(
lib = orauser,
table = patients_IR_BEN_R
);
data orauser.patients_IR_BEN_R;
set patients_IR_BEN_R;
run;
*
******************************************************************************************************
************************************;
* On récupère la ligne avec BEN_DTE_MAJ max pour chaque patient;
proc sql undo_policy = none;
%connectora;
CREATE TABLE BEN_DTE_MAJ_max AS
SELECT * FROM CONNECTION TO ORACLE (
SELECT
BEN_IDT_ANO,
MAX(BEN_DTE_MAJ) AS BEN_DTE_MAJ_max
FROM IR_BEN_R
GROUP BY BEN_IDT_ANO
);
disconnect from oracle;
quit;
%suppr_table(
lib = orauser,
table = BEN_DTE_MAJ_max
);
data orauser.BEN_DTE_MAJ_max;
set BEN_DTE_MAJ_max;
run;
*
******************************************************************************************************
************************************;
* On récupère les informations de ces patients;
proc sql undo_policy = none;
%connectora;
CREATE TABLE work.T_INDI_BPCO_&an_N. AS
SELECT * FROM CONNECTION TO ORACLE (
SELECT DISTINCT
a.BEN_IDT_ANO,
b.BEN_NIR_PSA,
b.BEN_RNG_GEM,
c.BEN_CDI_NIR,
c.BEN_NAI_ANN,
c.BEN_NAI_MOI,
c.BEN_SEX_COD,
c.BEN_DCD_DTE,
c.BEN_RES_DPT,
c.BEN_RES_COM,
SUBSTR(c.ORG_AFF_BEN, 1, 3) AS RGM_GRG_COD
FROM BEN_DTE_MAJ_max a
INNER JOIN patients_IR_BEN_R b
ON a.BEN_IDT_ANO = b.BEN_IDT_ANO
INNER JOIN IR_BEN_R c
ON a.BEN_IDT_ANO = c.BEN_IDT_ANO
AND a.BEN_DTE_MAJ_max = c.BEN_DTE_MAJ
);
disconnect from oracle;
quit;
data work.T_INDI_BPCO_&an_N. (rename = (BEN_DCD_DTE2 = BEN_DCD_DTE));
set work.T_INDI_BPCO_&an_N.;
length BEN_DCD_DTE2 4.;
BEN_DCD_DTE2 = datepart(BEN_DCD_DTE);
if BEN_DCD_DTE2 = "01JAN1600"d then
BEN_DCD_DTE2 = .;
format BEN_DCD_DTE2 date9.;
drop BEN_DCD_DTE;
run;
*
******************************************************************************************************
************************************;
* Exclusion des NIR fictifs;
data work.T_INDI_BPCO_&an_N.;
set work.T_INDI_BPCO_&an_N.;
exclus_NIR_fictif = "0";
if BEN_CDI_NIR ne "00" then
exclus_NIR_fictif = "1";
run;
*
******************************************************************************************************
************************************;
* Suppression des tables temporaires;
proc delete data = patients_IR_BEN_R BEN_DTE_MAJ_max;
run; quit;
proc delete data = orauser.patients_IR_BEN_R orauser.BEN_DTE_MAJ_max;
run; quit;
*
******************************************************************************************************
************************************;
* Vérifications;
* Variables BEN_CDI_NIR * EXCLUS_NIR_FICTIF;
%proc_freq(
in_tbl = work.T_INDI_BPCO_&an_N.,
out_tbl = _pop_NIR_FICTIF,
list_var_in = BEN_CDI_NIR*EXCLUS_NIR_FICTIF,
list_var_out = BEN_CDI_NIR EXCLUS_NIR_FICTIF Frequency
);
* Variable BEN_RES_DPT;
%proc_freq(
in_tbl = work.T_INDI_BPCO_&an_N.,
out_tbl = _pop_BEN_RES_DPT,
list_var_in = BEN_RES_DPT,
list_var_out = BEN_RES_DPT Frequency
);
* Variable BEN_SEX_COD;
%proc_freq(
in_tbl = work.T_INDI_BPCO_&an_N.,
out_tbl = _pop_BEN_SEX_COD,
list_var_in = BEN_SEX_COD,
list_var_out = BEN_SEX_COD Frequency
);

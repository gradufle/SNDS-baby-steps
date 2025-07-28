******************************************************************************************************
************************************ */
/*
*/
/* Options de la log et paramètres du projet (Autoexec_Options_de_la_log_et_parametres.sas)
*/
/*
*/
/*
******************************************************************************************************
************************************ */
*
******************************************************************************************************
************************************ ;
* Options de la log
;
*
******************************************************************************************************
************************************ ;
option nodate nonumber notes nosymbolgen ;
ods graphics on ;
option fmtsearch = (work library formats) nofmterr ;
*
******************************************************************************************************
************************************ ;
* Définition des paramètres
;
*
******************************************************************************************************
************************************ ;
* Année pour laquelle l indicateur est calculé;
%let annee_N = 2017;
%let an_N = %sysevalf(&annee_N. - 2000);
* Définitions des années N-4, N-2, N-1 et N+1 pour les recerches dans le DCIR et le PMSI;
%let annee_4N = %sysevalf(&annee_N. - 4);
%let annee_2N = %sysevalf(&annee_N. - 2);
%let annee_1N = %sysevalf(&annee_N. - 1);
%let annee_N1 = %sysevalf(&annee_N. + 1);
* Dernière version de la carto disponible;
%let version_carto = G6;
* Exclusion des clés de chainage incorrects;
* Peuvent être modifiées à chaque nouvelle pseudonymisation;
%let cle_inc1 = xxxxxxxxxxxxxxxxx;
%let cle_inc2 = BXXXXXXXXXXXXXXXX;
*

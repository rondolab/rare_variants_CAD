#Load regenie v. 2.0.2.
ml regenie/2.0.2

#Define path to working directory and create the following sub-directories: step1/, SNP_association/ and gene_burden/.
path=your_path_to_working_directory
mkdir /${path}/step1/
mkdir /${path}/SNP_association/
mkdir /${path}/gene_burden/

#Define number of jobs to run in parallel.
njobs=30

#Run regenie step 1 to fit a whole genome regression (*.loco files); these will then be used for single variant, biomarker and gene burden association tests in step 2. For more information on regenie parameters and file formats refer to https://rgcgithub.github.io/regenie/options/.

#Run regenie stage 0 - step 1.
regenie --step 1 --extract /${path}/qc_pass.snplist --keep /${path}/IDs_common.id --covarFile /${path}/covariates_file.txt --phenoFile /${path}/phenotype_file.txt --bsize 2000 --bed /${path}/plink_genotype_files_allchr --out /${path}/step1/fit_l0 --split-l0 /${path}/step1/fit_parallel,$njobs

#Run regenie stage 1 - step 1.
for job in $(seq 1 $njobs); do regenie --step 1 --extract /${path}/qc_pass.snplist --keep /${path}/IDs_common.id --covarFile /${path}/covariates_file.txt --phenoFile /${path}/phenotype_file.txt --bsize 2000 --bed /${path}/plink_genotype_files_allchr --out /${path}/step1/fit_l0_$job --run-l0 /${path}/step1/fit_parallel.master,$job ; done

#Run regenie stage 2 - step 1.
regenie --step 1 --extract /${path}/qc_pass.snplist --keep /${path}/IDs_common.id --covarFile /${path}/covariates_file.txt --phenoFile /${path}/phenotype_file.txt --bsize 2000 --bed /${path}/plink_genotype_files_allchr --out /${path}/step1/fit_l1 --run-l1 /${path}/step1/fit_parallel.master

#Ones *.loco files are stored in ${path}/step1/, run regenie step 2 for association testing.

#Run regenie step 2 to test single variants for association with ISCAD.
for i in $(seq 1 22); do regenie --step 2 --bed plink_exome_files_chr${i} --keep IDs_common.id --extract qc_pass_exome.snplist --phenoFile phenotype_file.txt --covarFile covariates_file.txt --pred step1/fit_l1_pred.list --bsize 500 --out SNP_association/single_variant_chr${i} ; done

#Run regenie step 2 for gene-burden association test.
for i in $(seq 1 22); do regenie --step 2 --bed plink_exome_files_chr${i} --keep IDs_common.id --extract qc_pass_exome_gene_burden.snplist --phenoFile phenotype_file.txt --covarFile covariates_file.txt --anno-file Anno_file.txt --set-list Set_list.txt --mask-def Mask_file.txt --pred step1/fit_l1_pred.list --bsize 500 --out gene_burden/gene_burden_chr${i}  --vc-tests skat,skato,acato-full ; done

#Run regenie step 2 to test single variants for association with clinical biomarkers.
for i in $(seq 1 22); do regenie --step 2 --bed plink_exome_files_chr${i} --keep IDs_common.id --extract qc_pass_exome.snplist --phenoFile phenotype_file_biomarkers.txt --covarFile covariates_file.txt --pred step1/fit_l1_pred.list --bsize 500 --out SNP_association/biomarkers_chr${i} ; done

#Run regenie step 2 to test gene-burdens for association with clinical biomarkers.
for i in $(seq 1 22); do regenie --step 2 --bed plink_exome_files_chr${i} --keep IDs_common.id --extract qc_pass_exome_gene_burden.snplist --phenoFile phenotype_file_biomarkers.txt --covarFile covariates_file.txt --anno-file Anno_file.txt --set-list Set_list.txt --mask-def Mask_file.txt --pred step1/fit_l1_pred.list --bsize 500 --out gene_burden/gene_burden_chr${i}  --vc-tests skat,skato,acato-full ; done

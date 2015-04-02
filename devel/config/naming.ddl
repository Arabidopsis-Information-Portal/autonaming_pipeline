
create table btab (
query_id text,
rundate date,
query_length integer,
program_name text,
job_name text,
subject_id text,
query_left integer,
query_right integer,
subject_left integer,
subject_right integer,
pct_identity float,
pct_similarity float,
raw_score float,
bit_score float,
alignment_length integer,
subject_definition text,
frame integer,
strand integer,
subject_length integer,
evalue float,
pvalue float );

create index btab_ix on btab( query_id, job_name );

create table btab_tmp (
query_id text,
rundate date,
query_length integer,
program_name text,
job_name text,
subject_id text,
query_left integer,
query_right integer,
subject_left integer,
subject_right integer,
pct_identity float,
pct_similarity float,
raw_score float,
bit_score float,
alignment_length integer,
subject_definition text,
frame integer,
strand integer,
subject_length integer,
evalue float,
pvalue float );

create index btab_tmp_ix on btab_tmp(subject_id,query_id);

create table htab (
hmm_acc text,
rundate date,
hmm_length integer,
program_name text,
job_name text,
query_id text,
hmm_begin integer,
hmm_end integer,
query_begin integer,
query_end integer,
unused text,
domain_score float,
total_score float,
domain_number integer,
num_domains integer,
hmm_definition text,
query_definition text,
trusted_cutoff float,
noise_cutoff float,
total_evalue float,
domain_evalue float,
unused2 text,
unused3 text,
unused4 text,
unused5 text );

create index htab_ix on htab( query_id, job_name );

create table htab_tmp (
hmm_acc text,
rundate date,
hmm_length integer,
program_name text,
job_name text,
query_id text,
hmm_begin integer,
hmm_end integer,
query_begin integer,
query_end integer,
unused text,
domain_score float,
total_score float,
domain_number integer,
num_domains integer,
hmm_definition text,
query_definition text,
trusted_cutoff float,
noise_cutoff float,
total_evalue float,
domain_evalue float,
unused2 text,
unused3 text,
unused4 text,
unused5 text );


create table priam (
  query_id text,
  ec_no text);
 
create unique index pk_priam on priam ( query_id, ec_no );

create table tmhmm (
  query_id text );

create unique index pk_tmhmm on tmhmm( query_id );

create table transcript_protein (
protein_id text,
transcript_id text );

create unique index transcript_protein_pk on transcript_protein(transcript_id,protein_id);

create table query_sequence (
query_id text );

create unique index query_sequence_pk on query_sequence(query_id);

CREATE TABLE hmm3 (
 	hmm_acc varchar,
	iso_type varchar );

create unique index pk_hmm3 on hmm3(hmm_acc);

create table hmm_go_link(
  hmm_acc varchar,
  go_term varchar,
  primary key(hmm_acc,go_term));

create unique index pk_hmm_go_link on hmm_go_link(hmm_acc,go_term);
 
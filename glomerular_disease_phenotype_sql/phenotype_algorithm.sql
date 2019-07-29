/*
This computable phenotype aims to identify patients with glomerular disease. The general algorithm is:
  - two occurrences of a diagnosis of glomerular disease (from a specified list)
  OR
  - one occurrence of a diagnosis of glomerular disease + a renal biopsy

A couple of the diagnoses for the first part of the algorithm (2+ occurrences) are not stand alone - one requires a specialty visit and the other requires another glomerular disease comorbidity.

The queries below are broken up into three general parts:
  - Part 1: Intermediary Tables: these tables are just setting up tables that will be used later. The output will be used in the Data Tables.
  - Part 2: Data Tables: these tables apply the algorithm and begin to identify the different components of the algorithm.
  - Part 3: Final Algorithm: this table is the final output that you will use in this study. It will generate a list of identifiers of CASES that will need to be validated via chart reviews. These identifiers will need to be mapped to MRNs where chart review will be performed locally.

I set the search path to 'glean' (where I am storing all the output generated for this study) and 'dcc_pedsnet' (tables in our 6-site database). Please set your search path accordingly. Thank you!

4/26 Update: This algorithm has the following changes:
  - Patients with two codes only of GS and no biopsy, and no other diagnostic code of interest, will be excluded from the study
  - Age at biopsy should be less than 30 yrs
  - Patients should not be in the death table

4/26 Update: I included a check of the algorithm at the bottom of the page

*/
set search_path to glean, dcc_pedsnet;
-- PART 1: INTERMEDIARY TABLES
-- Part 1, Table 1: big codeset, problem list and no problem list
create table big_codeset_vid_dates as
select distinct co.person_id, co.visit_occurrence_id, co.condition_start_date, 'no_flag' as problem_list_flag
from condition_occurrence co
inner join person p
  on co.person_id = p.person_id
where co.condition_concept_id in
  (
    4298809, 4125958, 4286024, 4128061, 4161421, 4260398, 4030513, 4263367, 4059452, 195289, 4027120, 4093431, 4222610, 4236844, 4056346, 4056478, 4125954, 4125955, 4128055, 4172011, 4241966, 4294813, 4008560, 4030514, 4056462, 4058840, 4058843, 4128065, 193253, 195314, 252365, 312358, 199071, 194405, 192364, 433257, 442075, 435320, 197319, 192362, 442074, 196464, 435003, 442076
  )
and co.condition_type_concept_id <> 38000245
and (co.condition_start_date - cast(p.birth_datetime as date)) < 365.25*30

union

select distinct co.person_id, co.visit_occurrence_id, co.condition_start_date, 'flag' as problem_list_flag
from condition_occurrence co
inner join person p
  on co.person_id = p.person_id
where co.condition_concept_id in
  (
    4298809, 4125958, 4286024, 4128061, 4161421, 4260398, 4030513, 4263367, 4059452, 195289, 4027120, 4093431, 4222610, 4236844, 4056346, 4056478, 4125954, 4125955, 4128055, 4172011, 4241966, 4294813, 4008560, 4030514, 4056462, 4058840, 4058843, 4128065, 193253, 195314, 252365, 312358, 199071, 194405, 192364, 433257, 442075, 435320, 197319, 192362, 442074, 196464, 435003, 442076
  )
and co.condition_type_concept_id in (2000000089, 2000000090, 2000000091)
and (co.condition_start_date - cast(p.birth_datetime as date)) < 365.25*30;

-- Part 1, Table 2: acute gn visits by care_site nephrologist OR physician nephrologist
create table acute_gn_vid_dates as
select distinct co.person_id, vo.visit_occurrence_id, co.condition_start_date, 'flag' as problem_list_flag
from condition_occurrence co
left join visit_occurrence vo
  on co.visit_occurrence_id = vo.visit_occurrence_id
left join care_site cs
  on cs.care_site_id = vo.care_site_id
left join provider pr
  on co.provider_id = pr.provider_id
inner join person p
  on co.person_id = p.person_id
where co.condition_concept_id in (435308, 259070)
and
  (
    cs.specialty_concept_id in (45756813, 38004479, 38003880)
    or
    pr.specialty_concept_id in (45756813, 38004479, 38003880)
  )
and condition_type_concept_id = 38000245
and (co.condition_start_date - cast(p.birth_datetime as date)) < 365.25*30

union

select distinct co.person_id, vo.visit_occurrence_id, co.condition_start_date, 'no_flag' as problem_list_flag
from condition_occurrence co
left join visit_occurrence vo
  on co.visit_occurrence_id = vo.visit_occurrence_id
left join care_site cs
  on cs.care_site_id = vo.care_site_id
left join provider pr
  on co.provider_id = pr.provider_id
inner join person p
    on co.person_id = p.person_id
where co.condition_concept_id in (435308, 259070)
and
  (
    cs.specialty_concept_id in (45756813, 38004479, 38003880)
    or
    pr.specialty_concept_id in (45756813, 38004479, 38003880)
  )
and condition_type_concept_id <> 38000245
and (co.condition_start_date - cast(p.birth_datetime as date)) < 365.25*30;

-- Part 1, Table 3: glomerulosclerosis, problem list and no problem list
create temporary table has_one_diag as
  select person_id, count(distinct condition_start_date) as cnt
  from condition_occurrence
  where condition_concept_id in
    (
      4298809, 4125958, 4286024, 4128061, 4161421, 4260398, 4030513, 4263367, 4059452, 195289, 4027120, 4093431, 4222610, 4236844, 4056346, 4056478, 4125954, 4125955, 4128055, 4172011, 4241966, 4294813, 4008560, 4030514, 4056462, 4058840, 4058843, 4128065, 193253, 195314, 252365, 312358, 199071, 194405, 192364, 433257, 442075, 435320, 197319, 192362, 442074, 196464, 435003, 442076
    )
  group by person_id
  having count(distinct condition_start_date) = 1;

create table gs_vid_dates as
select distinct co.person_id, co.visit_occurrence_id, co.condition_start_date, 'no_flag' as problem_list_flag
from condition_occurrence co
inner join person p
  on co.person_id = p.person_id
where co.condition_concept_id in
  (
    261071
  )
and co.condition_type_concept_id <> 38000245
and (co.condition_start_date - cast(p.birth_datetime as date)) < 365.25*30
and co.person_id in (select person_id from has_one_diag)

union

select distinct co.person_id, co.visit_occurrence_id, co.condition_start_date, 'flag' as problem_list_flag
from condition_occurrence co
inner join person p
  on co.person_id = p.person_id
where co.condition_concept_id in
  (
    261071
  )
and co.condition_type_concept_id in (2000000089, 2000000090, 2000000091)
and (co.condition_start_date - cast(p.birth_datetime as date)) < 365.25*30
and co.person_id in (select person_id from has_one_diag);

-- Part 2: DATA TABLES

-- Part 2, Table 1: counts for big codeset list minus gs and an table: 2+ visits
create table biglist_no_an_gs as
select case when a.person_id is not null then a.person_id else b.person_id end as person_id, coalesce(non_problem_list_count, 0) as non_problem_list_count,
      coalesce(problem_list_count, 0) as problem_list_count from
        (
          select person_id, count(distinct coalesce(visit_occurrence_id, 1)) as non_problem_list_count
            from
              (
                select person_id, visit_occurrence_id from big_codeset_vid_dates
                where problem_list_flag = 'no_flag'
              ) a
          group by person_id

        ) a -- Big Code List, NOT on problem list

      full join

        (
          select person_id, count(distinct condition_start_date) as problem_list_count
          from
          (
            select person_id, condition_start_date
            from big_codeset_vid_dates
            where problem_list_flag = 'flag'

            minus

            select person_id, condition_start_date
            from big_codeset_vid_dates
            where problem_list_flag = 'no_flag'
          ) a
          group by person_id
        ) b -- Big Code List, YES on problem list
    on a.person_id = b.person_id;

-- Part 2, Table 2: counts for an visits not in big codeset list
create table an_list as
select case when a.person_id is not null then a.person_id else b.person_id end as person_id, coalesce(non_problem_list_count, 0) as non_problem_list_count,
      coalesce(problem_list_count, 0) as problem_list_count from
        (
          select person_id, count(distinct coalesce(visit_occurrence_id, 1)) as non_problem_list_count
            from
              (
                select a.person_id, a.visit_occurrence_id from acute_gn_vid_dates a
                left join big_codeset_vid_dates b
                  on a.person_id = b.person_id and a.condition_start_date = b.condition_start_date
                where a.problem_list_flag = 'no_flag'
                and b.condition_start_date is null
                -- and b.problem_list_flag = 'flag'
                minus
                  (
                    select person_id, visit_occurrence_id from big_codeset_vid_dates
                  )
              ) a
            group by person_id

        ) a -- Big Code List, NOT on problem list

      full join
        (
          select person_id, count(distinct condition_start_date) as problem_list_count
          from
          (
            select person_id, condition_start_date from acute_gn_vid_dates
            where problem_list_flag = 'flag'

            minus
              (
                select person_id, condition_start_date from big_codeset_vid_dates
                union
                select person_id, condition_start_date from acute_gn_vid_dates
                  where problem_list_flag = 'no_flag'
              )

          ) a
          group by person_id
        ) b -- Big Code List, YES on problem list
    on a.person_id = b.person_id;

-- Part 2, Table 3: glomerulosclerosis
create table gs_list as
select case when a.person_id is not null then a.person_id else b.person_id end as person_id, coalesce(non_problem_list_count, 0) as non_problem_list_count, coalesce(problem_list_count, 0) as problem_list_count from
  (
    select person_id, count(distinct coalesce(visit_occurrence_id, 1)) as non_problem_list_count
    from
      (
        select v.person_id, visit_occurrence_id
        from gs_vid_dates v
        left join
          (
            select person_id, condition_start_date from big_codeset_vid_dates where problem_list_flag = 'flag'
              union
            select person_id, condition_start_date from acute_gn_vid_dates where problem_list_flag = 'flag'
          ) c on v.person_id = c.person_id and v.condition_start_date = c.condition_start_date
        where v.problem_list_flag = 'no_flag'
        and c.condition_start_date is null
        minus
          (
            select person_id, visit_occurrence_id from big_codeset_vid_dates
            union
            select person_id, visit_occurrence_id from acute_gn_vid_dates
          )
      ) b
    group by person_id

  ) a -- GS List, NOT on problem list

full join

  (
    select person_id, count(distinct condition_start_date) as problem_list_count
    from
    (
      select person_id, condition_start_date
      from gs_vid_dates
      where problem_list_flag = 'flag'

      minus
      (
        select person_id, condition_start_date from big_codeset_vid_dates
        union
        select person_id, condition_start_date from acute_gn_vid_dates
        union
        select person_id, condition_start_date from gs_vid_dates
        where problem_list_flag = 'no_flag'
      )
    ) a
    group by person_id
  ) b -- GS List, YES on problem list
on a.person_id = b.person_id;

-- Part 2, Table 4: Combining tables
create table combined_table_visits as
select case when bl.person_id is not null then bl.person_id
            when bl.person_id is null and an.person_id is not null then an.person_id
            else gs.person_id end as person_id,
      bl.non_problem_list_count as biglist_npl, bl.problem_list_count as biglist_pl,
      an.non_problem_list_count as an_npl, an.problem_list_count as an_pl,
      gs.non_problem_list_count as gs_npl, gs.problem_list_count as gs_pl,
      coalesce(bl.non_problem_list_count, 0) +
      coalesce(bl.problem_list_count, 0) +
      coalesce(an.non_problem_list_count,0) +
      coalesce(an.problem_list_count, 0) +
      coalesce(gs.non_problem_list_count, 0) +
      coalesce(gs.problem_list_count, 0) as total_visit_count
from biglist_no_an_gs bl
full join an_list an
  on bl.person_id = an.person_id
full join gs_list gs
  on an.person_id = gs.person_id;

--  Part 2, Table 5: procedure codes
create table all_biopsies as
select a.person_id, biopsy_date, transplant_date from
  (
    select distinct p.person_id, min(p.procedure_date) as biopsy_date
    from condition_occurrence c
    inner join procedure_occurrence p
      on c.person_id = p.person_id
    inner join person p2
      on p.person_id = p2.person_id
    where c.condition_concept_id in
      (
        259070, 4298809, 4125958, 4286024, 4128061, 4161421, 4260398, 4030513, 4263367, 4059452, 195289, 4027120, 4093431, 4222610, 4236844, 4056346, 4056478, 4125954, 4125955, 4128055, 4172011, 4241966, 4294813, 4008560, 4030514, 4056462, 4058840, 4058843, 4128065, 193253, 195314, 252365, 312358, 199071, 194405, 192364, 433257, 442075, 435320, 197319, 192362, 442074, 196464, 435003, 442076, 261071, 435308
      )
    and
      (
        p.procedure_concept_id in (2109566, 2003588)
    	   or
         (
           lower(procedure_source_value) like '%renal%' and procedure_concept_id = 2211783
         )
      )
    and (p.procedure_date - cast(p2.birth_datetime as date)) < 365.25*30
    group by p.person_id
  ) a

  left join

  (
    select distinct p.person_id, min(p.procedure_date) as transplant_date
    from procedure_occurrence p
    inner join person p2
      on p.person_id = p2.person_id
    where p.procedure_concept_id in
      (
        2003626, 45887600, 2109587, 2109586
      )
    and (p.procedure_date - cast(p2.birth_datetime as date)) < 365.25*30
    group by p.person_id
  ) b

  on a.person_id = b.person_id;

-- Part 3: Final Table
create table final_cohort as
  select person_id from
  (
    select person_id from combined_table_visits
      where total_visit_count >= 2

      union
      (
        select person_id from all_biopsies where biopsy_date < transplant_date
        union
        select person_id from all_biopsies where transplant_date is null
      )
  )

  where person_id not in
    (select person_id from death);

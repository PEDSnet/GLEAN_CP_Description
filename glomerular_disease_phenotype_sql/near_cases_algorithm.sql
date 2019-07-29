/*
The purpose of this query is to generate a list of 'near cases' to perform chart reviews.

The criteria are: patients who have had 3+ nephrology care site visits or provider visits who are NOT in the cases algorithm.
*/

set search_path to glean, dcc_pedsnet;

create table near_cases as
	select vo.person_id, count(distinct vo.visit_occurrence_id) as total_count
	from visit_occurrence vo
	left join care_site cs
		on cs.care_site_id = vo.care_site_id
	left join provider p
		on vo.provider_id = p.provider_id
	where
		(
			cs.specialty_concept_id in (45756813, 38004479, 38003880)
	    or
	    p.specialty_concept_id in (45756813, 38004479, 38003880)
		)
	and vo.person_id not in
		(
			select person_id from final_cohort
		)
	group by vo.person_id
	having count(distinct vo.visit_occurrence_id) >= 3
		;


		select * from near_cases where person_id = 1304759;

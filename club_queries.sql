--Стуктура таблицы users (первые 5 строк)
select *
from users u 
limit 5;

--Вывести всех пользователей младше 40 лет, отсортированных от старшего к младшему
select u.last_name, u.first_name, age
from users u 
where age <= 40
order by age desc;

--Вывести топ-5 самых дорогих мастер-классов
select h.hobby_name, om.cost, round(om.duration_seconds / 60.0)
from hobbies h 
join online_masterclasses om 
using (hobby_id)
order by cost desc
limit 5;

--Вывести мастер-классы с оценкой от 9 до 10, отсортированных по стоимости по убыванию
select h.hobby_name, om.cost, om.rate 
from hobbies h 
join online_masterclasses om 
using (hobby_id)
where om.rate between 9 and 10
order by om.cost desc;

--Посчитать: общее количество мастер-классов, общую выручку, среднюю стоимость и среднюю оценку
select count(record_id) as count_of_mc, sum(cost) as revenue, round(avg(cost),2) as avg_cost, round(avg(rate),1) as avg_rate
from online_masterclasses;

--Найти минимальную и максимальную длительность мастер-класса (в минутах)
select round(min(duration_seconds / 60.0),2) as min_minutes, round(max(duration_seconds / 60.0),2) as max_minutes
from online_masterclasses;

--Посчитать, сколько пользователей указали хотя бы одно хобби 
select count(distinct user_id)
from user_hobbies;

--Для каждого хобби вывести: название, среднюю стоимость, среднюю оценку, упорядочить по количеству мастер-классов
select h.hobby_name,count(om.record_id) as count_id, round(avg(om.cost),2) as avg_cost, round(avg(om.rate),1) as avg_rate
from hobbies h 
join online_masterclasses om 
using (hobby_id)
group by h.hobby_name 
order by count_id desc;

--Для каждого пользователя вывести: количество мастер-классов и общую сумму потраченных денег. Отсортировать по убыванию суммы, огранича в 5 строк
select u.last_name, u.first_name, count(om.record_id), sum(om.cost) as sum_cost
from users u  
join online_masterclasses om 
using (user_id)
group by u.user_id
order by sum_cost desc
limit 5;

--Для каждого хобби показать: название хобби, минимальную стоимость мастер-класса, максимальную стоимость, разницу между максимальной и максимальной стоимостью
--Отсортировать по разнице от большей к меньшей
select h.hobby_name, min(om.cost) as min_cost, max(cost) as max_cost, (max(cost) - min(om.cost) ) as difference
from hobbies h 
join online_masterclasses om 
using (hobby_id)
group by h.hobby_name
order by difference
limit 3;

--Вывести всех пользователей с названиями их хобби
select h.hobby_name, u.last_name, u.first_name
from hobbies h 
join online_masterclasses om 
using (hobby_id)
join users u 
using (user_id);

--Вывести всех пользователей и их достижения
select *
from users u  
left join achievements a 
using (user_id);

--Найти пользователей, у которых нет ни одного достижения 
select *
from users u  
left join achievements a 
using (user_id)
where a.achievement_id isnull;

--Вывести для каждого мастер-класса: фамилию и имя пользователя, название хобби, стоимость и оценку. Ограничить вывод 20 строками
select h.hobby_name, u.last_name, u.first_name, om.cost, om.rate
from hobbies h 
join online_masterclasses om 
using (hobby_id)
join users u 
using (user_id)
limit 20;

--Найти пользователей, у которых суммарная стоимость мастер-классов выше средней суммы по всем пользователям
with avg_total AS 
	(select avg(sum_cost) as avg_cost
		from
			(select sum(om.cost) as sum_cost
			from online_masterclasses om
			group by  om.user_id)
	)
select u.last_name, u.first_name, sum(om.cost) as sum_cost
from users u  
join online_masterclasses om 
using (user_id)
group by u.user_id, u.last_name, u.first_name 
having sum_cost > (select avg_cost from avg_total);

--Для каждого пользователя вывести: фамилию и имя пользователя, общую потраченную сумму, ранг по этой сумме (от большего к меньшему)
select last_name, first_name, sum_cost,
rank () over (order by sum_cost desc) as grade
from
(
	select u.last_name, u.first_name, sum(om.cost) as sum_cost
	from users u  
	join online_masterclasses om 
	using (user_id)
	group by u.user_id
)

--Вычислить медианную стоимость мастер-класса
with ranked as (
	select cost,
		row_number() over (order by cost) as rn,
		count(*) over () as cnt
	from online_masterclasses
	where cost is not null
)
select round((avg(cost)), 2) as median_cost
from ranked 
where rn in ((cnt + 1) /2, (cnt + 2) / 2);

--Вычислить дисперсию и стандартное отклонение длительности 
with stats as (
	select avg(duration_seconds) as mean_duration,
	count (*) as n
	from online_masterclasses
)
select round(sum((duration_seconds - mean_duration) * (duration_seconds - mean_duration)) / (n - 1), 2) as variance,
round(sqrt(sum((duration_seconds - mean_duration) * (duration_seconds - mean_duration)) / (n - 1)), 2) as stddev
from online_masterclasses, stats;

--Выбросы по IQR. Найти: мастер-классы, стоимость которых явдяется выбросом
with ordered as (
	select cost,
		row_number() over (order by cost) as row_num,
		count(*) over () as total_count
	from online_masterclasses
),
quartiles as (
	select 
		avg(case when row_num between round(total_count * 0.25) and round(total_count * 0.25) + 1 then cost end) as q1,
		avg(case when row_num between round(total_count * 0.75) and round(total_count * 0.75) + 1 then cost end) as q3
	from ordered
)
select u.last_name, u.first_name, h.hobby_name, om.cost,
case
	when om.cost > q3 + 1.5 * (q3 -q1) then 'Выброс:(слишком дорого)'
	else 'Выброс:(слишком дёшево)'
end as outliner_type
from online_masterclasses om 
join users u 
using (user_id)
join hobbies h 
using (hobby_id)
cross join quartiles 
where om.cost > q3 + 1.5 * (q3 -q1) or om.cost < q1 - 1.5 * (q3 -q1);

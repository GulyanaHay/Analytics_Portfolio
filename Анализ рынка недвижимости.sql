--Задача 1 Время активности объявлений

-- Определим аномальные значения (выбросы) по значению перцентилей
-- Найдём id объявлений, которые не содержат выбросы
--В основном запросе разделим объявления на регионы: г.Санкт-Петербург и Ленинградская область. 
    --Также разделим объявления на 4 периода: до месяца, до трех месяцев, до полугода, более полугода
    --Выведем количество объявлений, среднюю стоимость 1 кв. метра квартиры, среднюю площадь квартиры, медианы: комнат, балконов, этажности
    --Объединим таблицы: flats, city, type, advertisement по ключам
    --Проведем фильтрацию по типу населенного пункта - город; по объявлениям, снятым с публикации
    --Также проведем фильтрацию по объявлениям, которые не содержат выбросы
    --Сгруппируем по региону Санкт Петербург и Ленинградская область и по количеству дней активности объявлений
    --Сортируем по региону
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
    SELECT CASE 
	   WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
       ELSE 'ЛенОбл' 
       END AS регион,
       CASE 
       WHEN days_exposition<=30
       THEN 'До месяца'
       WHEN days_exposition>=31 AND days_exposition<=90
       THEN 'До трех месяцев'
       WHEN days_exposition>=91 AND days_exposition<=180
       THEN 'До полугода'
       ELSE 'Более полугода'
       END AS активность, 
       COUNT (f.id) AS количество_объявлений,
       ROUND (AVG(last_price /total_area):: numeric,2) AS Средняя_стоимость_квадратного_метра,
       ROUND (AVG(total_area):: numeric,2) AS Сред_площадь_кварт,
       percentile_disc (0.5) WITHIN GROUP (ORDER BY rooms) AS медиана_комнат,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY balcony) AS медиана_балконов,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY floor) AS медиана_этажности
FROM real_estate.flats as f
JOIN real_estate.city as c on f.city_id = c.city_id
JOIN real_estate.type as t on f.type_id = t.type_id
JOIN real_estate.advertisement AS a on f.id=a.id
WHERE type ='город' AND days_exposition IS NOT NULL AND f.id IN (SELECT * FROM filtered_id)
GROUP BY регион, активность
ORDER BY регион DESC;

-- Задача 2 Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей
-- Найдём id объявлений, которые не содержат выбросы
-- В основном запросе выделяем месяцы из даты публикации объявлений
-- Выведем количество опубликованных объявлений и отдельно количество снятых объявлений, выведем долю снятых объявлений по отношению к опубликованным
-- Ранжируем месяцы отдельно по опубликованным объявлениям и снятым объявлениям
-- Выведем отдельно для опубликованных объявлений и снятых объявлений среднюю стоимость квадратного метра и среднюю площадь квартиры
-- Объединим таблицы: flats, city, type, advertisement по ключам
-- Проведем фильтрацию по типу населенного пункта - город; по дате публикации по полным годам с 2015г по 2018г
-- Также проведем фильтрацию по объявлениям, которые не содержат выбросы
-- Сгруппируем и сортируем по месяцам
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
      SELECT
    EXTRACT (MONTH FROM a.first_day_exposition) AS месяц,
    COUNT (a.id) AS Кол_во_опубл_объявлений,
    COUNT (a.id) filter (WHERE days_exposition > 0) AS Кол_во_снятых_объявлений,
    COUNT (a.id) filter (WHERE days_exposition > 0) *100 / COUNT (a.id) AS Доля_снятых_объявл,
    DENSE_RANK () OVER (ORDER BY (COUNT (a.id))DESC) AS ранг_опубл,
     DENSE_RANK () OVER (ORDER BY (COUNT (a.id) filter (WHERE days_exposition > 0))DESC) AS ранг_снятых,
     ROUND (AVG(last_price /total_area):: numeric,2) AS Сред_стоимость_кв_метра_опубл_объявл,
     ROUND (AVG(total_area):: numeric,2) AS Сред_площадь_кварт_опубл_объявл,
     ROUND (AVG(last_price /total_area) FILTER (WHERE days_exposition > 0)::numeric,2) AS Сред_стоимость_кв_метра_снят_объявл,
      ROUND (AVG(total_area) FILTER (WHERE days_exposition > 0)::numeric,2) AS Сред_площадь_кварт_снят_объявл
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f on a.id = f.id
    JOIN real_estate.city as c on f.city_id = c.city_id
    JOIN real_estate.type as t on f.type_id = t.type_id
    WHERE type ='город' AND f.id IN (SELECT * FROM filtered_id)
    AND EXTRACT (YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
    GROUP BY месяц
   ORDER BY месяц;
  
  -- Задача 3 Анализ рынка недвижимости Лен области
  -- Определим аномальные значения (выбросы) по значению перцентилей
  -- Найдём id объявлений, которые не содержат выбросы
  -- В основном запросе выведем название города Ленинградской области
  -- Выведем общее количество объявлений, посчитаем долю снятых объявлений по отношению к общему количеству и выведем количество активных объявлений
  -- Выведем среднюю стоимость 1 кв. метра квартиры, среднюю площадь квартиры
  -- Выведем среднюю продолжительность размещения объявлений в днях	 
  -- Объединим таблицы: flats, city, type, advertisement по ключам
  -- Проведем фильтрацию по названию города, чтобы было не равно Санкт-Петербург
  -- Также проведем фильтрацию по объявлениям, которые не содержат выбросы
  -- Сгруппируем по названиям городов Ленинградской области
  -- Сортируем по количеству объявлений в порядке убывания
  -- Выведем топ-15
  WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
    SELECT c.city AS Город_Лен_обл,
    COUNT (f.id) AS количество_объявлений,
    COUNT (a.id) filter (WHERE days_exposition > 0) *100 / COUNT (a.id) AS Доля_снятых_объявл,
    COUNT (f.id) - COUNT (a.id) filter (WHERE days_exposition > 0) AS Кол_во_активных_объявлений,
    ROUND (AVG(last_price /total_area):: numeric,2) AS Сред_стоимость_кв_метра,
    ROUND (AVG(total_area):: numeric,2) AS Сред_площадь_квартиры,
    ROUND (AVG (a.days_exposition)) AS сред_продолжит_размещения
    FROM real_estate.flats as f
JOIN real_estate.city as c on f.city_id = c.city_id
JOIN real_estate.type as t on f.type_id = t.type_id
JOIN real_estate.advertisement AS a on f.id=a.id
WHERE f.id IN (SELECT * FROM filtered_id) AND city <> 'Санкт-Петербург'
GROUP BY Город_Лен_обл
ORDER BY количество_объявлений DESC
LIMIT 15;


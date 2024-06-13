use mavenfuzzyfactory;

/*
1. show volume growth. pull overall session and order volume, trended by quarter for the life of the business.
And the most recent quarter is incomplete, you can decide how to handle it
*/

SELECT
	year(website_sessions.created_at) AS yr,
    quarter(website_sessions.created_at) AS qtr,
    count(distinct website_sessions.website_session_id) AS sessions,
    count(distinct orders.order_id) AS orders
FROM website_sessions
	left join orders
		on website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;

/*
2. show efficiency improvements. show quarterly figures since we launched, for session-to-order conversion rate, 
revenue per order, and revenue per session.
*/
 
select
	year(website_sessions.created_at) AS yr,
    quarter(website_sessions.created_at) AS qtr,
    count(distinct orders.order_id)/count(distinct website_sessions.website_session_id) as session_to_order_conv_rate,
    sum(price_usd)/count(distinct orders.order_id) as revenue_per_order,
    sum(price_usd)/count(distinct website_sessions.website_session_id) as revenue_per_session
from website_sessions
	left join orders
		on website_sessions.website_session_id = orders.website_session_id
group by 1,2
order by 1,2
;

/*
3. show we've grown specific channels. pull a quarterly view of orders from 
Gsearch nonbrand, Bsearch nonbrand, brand search overall, organic search, and direct type-in 
*/

select
	year(website_sessions.created_at) AS yr,
    quarter(website_sessions.created_at) AS qtr,
    count(distinct case when utm_source = 'gsearch' and utm_campaign = 'nonbrand' then orders.order_id else null end) as gsearch_nonbrand_orders,
    count(distinct case when utm_source = 'bsearch' and utm_campaign = 'nonbrand' then orders.order_id else null end) as bsearch_nonbrand_orders,
	count(distinct case when utm_campaign = 'brand' then orders.order_id else null end) as brand_search_orders,
    count(distinct case when utm_source is null and http_referer is not null then orders.order_id else null end) as organic_search_orders,
    count(distinct case when utm_source is null and http_referer is null then orders.order_id else null end) as direct_type_in_orders
from website_sessions
	left join orders
		on website_sessions.website_session_id = orders.website_session_id
group by 1,2
order by 1,2
;

/*
4. show the overall session-to-order conversion rate for those same channels, by quarter
make a note of any periods where we made same major improvements or optimizations.
*/

select
	year(website_sessions.created_at) AS yr,
    quarter(website_sessions.created_at) AS qtr,
    count(distinct case when utm_source = 'gsearch' and utm_campaign = 'nonbrand' then orders.order_id else null end)
		/count(distinct case when utm_source = 'gsearch' and utm_campaign = 'nonbrand' then website_sessions.website_session_id else null end) as gsearch_nonbrand_conv_rt,
	count(distinct case when utm_source = 'bsearch' and utm_campaign = 'nonbrand' then orders.order_id else null end)
		/count(distinct case when utm_source = 'bsearch' and utm_campaign = 'nonbrand' then website_sessions.website_session_id else null end) as bsearch_nonbrand_conv_rt,
	count(distinct case when utm_campaign = 'brand' then orders.order_id else null end)
		/count(distinct case when utm_campaign = 'brand' then website_sessions.website_session_id else null end) as brand_search_conv_rt,
	count(distinct case when utm_source is null and http_referer is not null then orders.order_id else null end)
		/count(distinct case when utm_source is null and http_referer is null then website_sessions.website_session_id else null end) as organic_search_conv_rt,
	count(distinct case when utm_source is null and http_referer is null then orders.order_id else null end)
		/count(distinct case when utm_source is null and http_referer is null then website_sessions.website_session_id else null end) as direct_type_in_conv_rt
	from website_sessions
		left join orders
			on website_sessions.website_session_id = orders.website_session_id
group by 1,2
order by 1,2;

/*
5. pull monthly trending for revenue and margin by product, along with total sales and revenue. 
note anything you notice about seasonality.
*/

select
	year(created_at) as yr,
    month(created_at) as mo,
    sum(case when product_id = 1 then price_usd else null end) as mrfuzzy_rev,
    sum(case when product_id = 1 then price_usd - cogs_usd else null end) as mrfuzzy_marg,
    sum(case when product_id = 2 then price_usd else null end) as lovebear_rev,
    sum(case when product_id = 2 then price_usd - cogs_usd else null end) as lovebear_marg,
    sum(case when product_id = 3 then price_usd else null end) as birthdaybear_rev,
    sum(case when product_id = 3 then price_usd - cogs_usd else null end) as birthdaybear_marg,
    sum(case when product_id = 4 then price_usd else null end) as minibear_rev,
    sum(case when product_id = 4 then price_usd - cogs_usd else null end) as minibear_marg,
    sum(price_usd) as total_revenue,
    sum(price_usd - cogs_usd) as total_margin
from order_items
group by 1,2
order by 1,2;

/*
6. dive deeper into the impact of introducing new products.
pull monthly sessions to /product page, show the % of those sessions clicking through another page has changed over time,
along with a view of how conversion from products to placing an order has improved.
*/

-- first, identify all the views of the /product page
create temporary table product_pageviews
select
	website_session_id,
    website_pageview_id,
    created_at as saw_product_page_at
from website_pageviews
where pageview_url = '/products';

select
	year(saw_product_page_at) as yr,
    month(saw_product_page_at) as mo,
    count(distinct product_pageviews.website_session_id) as sessions_to_product_page,
    count(distinct wp.website_session_id) as clicked_to_next_page,
	count(distinct wp.website_session_id)/count(distinct product_pageviews.website_session_id) as clickthrough_rt,
    count(distinct o.order_id) as orders,
    count(distinct o.order_id)/count(distinct product_pageviews.website_session_id) as products_to_order_rt
from product_pageviews
	left join website_pageviews wp
		on wp.website_session_id = product_pageviews.website_session_id -- same session
        and wp.website_pageview_id > product_pageviews.website_pageview_id -- another page after
	left join orders o
		on o.website_session_id = product_pageviews.website_pageview_id
group by 1,2;

/*
7. We made our 4th products available as a primary product on December 05, 2014 (cross-sell item previously)
pull sales data since then, show how well each product cross-sells from one another
*/

create temporary table primary_products
select
	order_id,
    primary_product_id,
    created_at as ordered_at
from orders
where created_at > '2014-12-05';

select
	primary_product_id,
    count(distinct order_id) as total_orders,
    count(distinct case when cross_sell_product_id = 1 then order_id else null end) as _xsold_p1,
    count(distinct case when cross_sell_product_id = 2 then order_id else null end) as _xsold_p2,
    count(distinct case when cross_sell_product_id = 3 then order_id else null end) as _xsold_p3,
    count(distinct case when cross_sell_product_id = 4 then order_id else null end) as _xsold_p4,
    count(distinct case when cross_sell_product_id = 1 then order_id else null end)/count(distinct order_id) as p1_xsell_rt,
    count(distinct case when cross_sell_product_id = 2 then order_id else null end)/count(distinct order_id) as p2_xsell_rt,
    count(distinct case when cross_sell_product_id = 3 then order_id else null end)/count(distinct order_id) as p3_xsell_rt,
    count(distinct case when cross_sell_product_id = 4 then order_id else null end)/count(distinct order_id) as p4_xsell_rt
    from
    (
    select
		primary_products.*,
        order_items.product_id as cross_sell_product_id
	from primary_products
		left join order_items
			on order_items.order_id = primary_products.order_id
            and order_items.is_primary_item = 0 -- only bringing in cross-sells
	) as primary_w_cross_sell
    group by 1;
    

    
    

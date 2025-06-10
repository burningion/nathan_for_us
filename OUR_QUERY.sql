select
  false as "is_sub_account",
  v.name as "vendor_name",
  rmp.name as "platform_name",
  coalesce(a.display_name, a.name) as "account_name",
  null as "sub_account_name",
  a.external_id as "account_external_id",
  null as "sub_account_external_id",
  a.skai_profile_id,
  a.skai_channel_id,
  a.currency_code,
  a.country_code,
  v.code as "vendor_code",
  rmp.code as "platform_code"
from accounts a
join vendors v on a.vendor_id = v.id
left join retail_media_platforms rmp on a.retail_media_platform_id = rmp.id
where a.skai_profile_id is not null
union all
select
  true as "is_sub_account",
  v.name as "vendor_name",
  rmp.name as "platform_name",
  coalesce(a.display_name, a.name) as "account_name",
  sub.name as "sub_account_name",
  a.external_id as "account_external_id",
  sub.external_id as "sub_account_external_id",
  sub.skai_profile_id,
  sub.skai_channel_id,
  a.currency_code,
  a.country_code,
  v.code as "vendor_code",
  rmp.code as "platform_code"
from sub_accounts sub
join accounts a on sub.account_id = a.id
join vendors v on a.vendor_id = v.id
left join retail_media_platforms rmp on a.retail_media_platform_id = rmp.id
where sub.skai_profile_id is not null
order by "vendor_name", "account_name", "sub_account_name"

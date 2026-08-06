-- Change the referral signup reward from 50 tokens to 10 tokens per signup.
-- (030_affiliate_tokens.sql set the original default of 50; this updates the
-- singleton settings row for databases where that migration already ran.)

UPDATE affiliate_token_settings
SET signup_bonus_tokens = 10
WHERE id = true;

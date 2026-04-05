-- ============================================================
-- Salarn — SQL Schema Improvements & Fixes
-- Run this AFTER the main schema is installed
-- ============================================================

-- Improve transactions table with better constraints
ALTER TABLE public.transactions
  ADD CONSTRAINT crypto_amount_valid 
    CHECK (crypto_symbol IS NULL OR crypto_amount > 0);

-- Add index for faster admin filtering
CREATE INDEX IF NOT EXISTS transactions_reviewed_at_idx 
  ON public.transactions(reviewed_at DESC);

-- Add index for copy trade lookups
CREATE INDEX IF NOT EXISTS copy_trades_trader_id_active_idx 
  ON public.copy_trades(trader_id, is_active);

-- Add UNIQUE constraint to prevent duplicate active copy trades per trader
ALTER TABLE public.copy_trades
  ADD CONSTRAINT unique_active_copy_trade 
    UNIQUE (user_email, trader_id) 
    WHERE is_active = true;

-- Improve portfolio index for faster lookups
DROP INDEX IF EXISTS portfolio_user_email_idx;
CREATE INDEX IF NOT EXISTS portfolio_user_email_crypto_idx 
  ON public.portfolio(user_email, crypto_symbol);

-- Add function to calculate total portfolio value (useful for analytics)
CREATE OR REPLACE FUNCTION public.get_portfolio_value(p_user_email TEXT)
RETURNS NUMERIC AS $$
DECLARE
  total_value NUMERIC := 0;
  p_row RECORD;
  crypto_price NUMERIC;
BEGIN
  FOR p_row IN
    SELECT crypto_symbol, amount FROM public.portfolio 
    WHERE user_email = p_user_email
  LOOP
    SELECT price INTO crypto_price 
    FROM public.cryptocurrencies 
    WHERE symbol = p_row.crypto_symbol LIMIT 1;
    
    total_value := total_value + ((crypto_price OR 0) * p_row.amount);
  END LOOP;
  
  RETURN total_value;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ============================================================
-- DONE
-- ============================================================

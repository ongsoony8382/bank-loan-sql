SET @c=NULL; SET @a=NULL; SET @t=NULL; SET @pd=NULL;
SET @dt=NULL; SET @intr=NULL; SET @rpm=NULL;

CALL SP_GET_LOAN_APLY(1, @c, @a, @t, @pd, @dt, @intr, @rpm);

SELECT @c, @a, @t, @pd, @dt, @intr, @rpm;

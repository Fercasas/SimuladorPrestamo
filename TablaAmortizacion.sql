SET NOCOUNT ON

/*Parametros iniciales*/
DECLARE
--Importe o valor del prestamo
@Importe MONEY = 100000000
DECLARE
--Plazo en meses
@PLazo INT = 180
DECLARE
--Tasa Efectiva Anual (porcentaje)
@TasaAnual FLOAT = 15.48
DECLARE
--Valor mensual por productos externos como seguros
@Externos MONEY = 0

BEGIN
    DECLARE @Mensaje      VARCHAR (250)
          , @MensajeError VARCHAR (250)
          , @Int          FLOAT
          , @CuotaBase    MONEY
          , @Principal    MONEY
          , @Intereses    MONEY
          , @PpalPte      MONEY

    BEGIN TRY
        SET @Mensaje = '>>> Validaciones'

        PRINT @Mensaje

        IF @Importe <= 0
        BEGIN
            SET @MensajeError = 'El importe no puede ser menor o igual que cero'

            RAISERROR(@MensajeError, 16, 1)
        END

        IF @TasaAnual < 0
        BEGIN
            SET @MensajeError = 'La tasa efectiva anual no puede ser menor que cero'

            RAISERROR(@MensajeError, 16, 1)
        END

        IF @PLazo < 1
        BEGIN
            SET @MensajeError = 'El plazo no puede ser menor a 1 mes'

            RAISERROR(@MensajeError, 16, 1)
        END

        SET @Mensaje = CONCAT(CHAR(9), '> Importe: ', @Importe)
        PRINT @Mensaje

        SET @Mensaje = CONCAT(CHAR(9), '> TEA: ', @TasaAnual, ' %')
        PRINT @Mensaje

        SET @Mensaje = CONCAT(CHAR(9), '> Plazo: ', @PLazo, ' Meses')
        PRINT @Mensaje

        SET @Mensaje = CONCAT(CHAR(9), '> Producto externos: ', @Externos)
        PRINT @Mensaje

        SET @Mensaje = '>>> Calculos iniciales'
        PRINT @Mensaje

        IF @TasaAnual > 0
        BEGIN
            SELECT @Int = ROUND(((POWER((1 + (@TasaAnual / 100)), (0.0833333333333333))) - 1), 4)

            SET @Mensaje = CONCAT(CHAR(9), '> TNM: ', @Int * 100, ' %')
            PRINT @Mensaje

            SELECT @CuotaBase = CEILING((@Int + @Int / (POWER(1 + @Int, @PLazo) - 1)) * @Importe)
            SELECT @CuotaBase = IIF(@CuotaBase > @Importe + @Int * @Importe, @Importe + @Int * @Importe, @CuotaBase)
        END
        ELSE
        BEGIN
            SELECT @Int = 0
            SELECT @CuotaBase = CEILING(@Importe / @PLazo)
        END

        SET @Mensaje = CONCAT(CHAR(9), '> Cuota mensual: ', @CuotaBase + @Externos)
        PRINT @Mensaje

        SELECT @Principal = CAST(ROUND(@CuotaBase - @Importe * @Int, 0) AS MONEY)
        SELECT @Intereses = CAST(ROUND(@Importe * @Int, 0) AS MONEY)
        SELECT @PpalPte = CAST(ROUND(@Importe - @Principal, 0) AS MONEY)

        SET @Mensaje = '>>> Generar tabla de amortización'
        PRINT @Mensaje;

        WITH Amortizacion
        AS (SELECT 1                      AS Periodo
                 , @CuotaBase             AS CuotaBase
                 , @CuotaBase + @Externos AS Cuota
                 , @Principal             AS Principal
                 , @Intereses             AS Intereses
                 , @Externos              AS Externos
                 , @PpalPte               AS PpalPte
            UNION ALL
            SELECT [Amortizacion].[Periodo] + 1                                   AS Periodo
                 , CASE
                       WHEN [Amortizacion].[PpalPte] + ROUND([Amortizacion].[PpalPte] * @Int, 0) < [Amortizacion].[CuotaBase] THEN
                           CAST([Amortizacion].[PpalPte] + ROUND([Amortizacion].[PpalPte] * @Int, 0) AS MONEY)
                       ELSE
                           [Amortizacion].[CuotaBase]
                   END                                                            AS CuotaBase
                 , CASE
                       WHEN [Amortizacion].[PpalPte] + ROUND([Amortizacion].[PpalPte] * @Int, 0) < [Amortizacion].[CuotaBase] THEN
                           CAST([Amortizacion].[PpalPte] + ROUND([Amortizacion].[PpalPte] * @Int, 0) AS MONEY)
                       ELSE
                           [Amortizacion].[CuotaBase]
                   END + [Amortizacion].[Externos]                                AS Cuota
                 , CAST(CASE
                            WHEN [Amortizacion].[PpalPte] + ROUND([Amortizacion].[PpalPte] * @Int, 0) < [Amortizacion].[CuotaBase] THEN
                                CAST([Amortizacion].[PpalPte] + ROUND([Amortizacion].[PpalPte] * @Int, 0) AS MONEY)
                            ELSE
                                [Amortizacion].[CuotaBase]
                        END - ROUND([Amortizacion].[PpalPte] * @Int, 0) AS MONEY) AS Principal
                 , CAST(ROUND([Amortizacion].[PpalPte] * @Int, 0) AS MONEY)       AS Intereses
                 , [Amortizacion].[Externos]
                 , CAST(ROUND(   [Amortizacion].[PpalPte] - (CASE
                                                                 WHEN [Amortizacion].[PpalPte] + ROUND([Amortizacion].[PpalPte] * @Int, 0) < [Amortizacion].[CuotaBase] THEN
                                                                     CAST([Amortizacion].[PpalPte] + ROUND([Amortizacion].[PpalPte] * @Int, 0) AS MONEY)
                                                                 ELSE
                                                                     [Amortizacion].[CuotaBase]
                                                             END - [Amortizacion].[PpalPte] * @Int
                                                            )
                               , 0
                             ) AS MONEY)                                          AS PpalPte
            FROM Amortizacion
            WHERE Periodo < @PLazo)
        SELECT CONCAT('Mes', ' ', [A].[Periodo]) AS Periodo
             , [A].[CuotaBase]
             , [A].[Cuota]
             , [A].[Principal]
             , [A].[Intereses]
             , [A].[Externos]
             , [A].[PpalPte]
        FROM Amortizacion AS A
        OPTION (MAXRECURSION 500)
    END TRY
    BEGIN CATCH
        SET @MensajeError = CONCAT('ERROR', ' [', COALESCE(@Mensaje, ''), ']: ', COALESCE(ERROR_MESSAGE(), ''))

        RAISERROR(@MensajeError, 16, 1)
    END CATCH
END

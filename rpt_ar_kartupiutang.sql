USE [pms_ppub_plspk]
GO

/****** Object:  StoredProcedure [dbo].[rpt_ar_kartupiutang]    Script Date: 10/02/2023 14:13:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================

--EXEC rpt_ar_kartupiutang @ret_contract_no = 'TCP000001',@ret_query = 3
 
CREATE OR ALTER PROCEDURE [dbo].[rpt_ar_kartupiutang]
	-- Add the parameters for the stored procedure here
	@ret_contract_no as varchar(20),
	@ret_query as int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @PPN_Data_Kontrak AS numeric(18,0)
	DECLARE @LPP AS numeric(18,0)
	DECLARE @KaryaYDF_Cair AS numeric(18,0)
	DECLARE @KaryaYDF_NonCair AS numeric(18,0)
	DECLARE @Jumlah_PPN_Cair AS numeric(18,0)
	DECLARE @Jumlah_PPN_NonCair AS numeric(18,0)
	DECLARE @Jumlah_IncFinal_Cair AS numeric(18,0)
	DECLARE @Jumlah_IncFinal_NonCair AS numeric(18,0)
	DECLARE @PPN_Final_Cair AS numeric(18,0)
	DECLARE @PPN_Final_NonCair AS numeric(18,0)
	DECLARE @PPH_Final_Cair AS numeric(18,0)
	DECLARE @PPH_Final_NonCair AS numeric(18,0)
	DECLARE @Potongan_UM_Cair AS numeric(18,0)
	DECLARE @Potongan_UM_Noncair AS numeric(18,0)
	DECLARE @Potongan_Retensi_Cair AS numeric(18,0)
	DECLARE @Potongan_Retensi_Noncair AS numeric(18,0)
	DECLARE @Jumlah_Bersih_Cair AS numeric(18,0)
	DECLARE @Jumlah_Bersih_NonCair AS numeric(18,0)
	DECLARE @Jumlah_Diterima_Cair AS numeric(18,0)
	DECLARE @Jumlah_Diterima_NonCair AS numeric(18,0)
	DECLARE @int AS int

---------------------------------------------------------------------Insert Temporary #Termyn_Cair_NonCair---------------------------------------------------------------------

			IF OBJECT_ID('tempdb..#Termyn_Cair_NonCair') IS NOT NULL DROP TABLE #Termyn_Cair_NonCair

			SELECT	

					contractor_id,		[Nama owner],					[Alamat Owner],					[Sumber Dana],			
					TERMYNKE,			Tanggal_Bap,					Round(cast([%] as int),0)[%],	KARYAYDF,
					CAST(Potongan_UM AS numeric(18,0))Potongan_UM,										CAST(Potongan_Ret AS numeric(18,0)) Potongan_Ret,
					CAST(Jumlah_Bersih AS numeric(18,0)) Jumlah_Bersih,									CAST(PPN_2005 AS numeric(18,0)) PPN_2005,
					Cast((Jumlah_Bersih + PPN_2005) as numeric(18,0)) [Jumlah Inc PPN] ,				Cast(PPH_Final as numeric(18,0))PPH_Final,
					Cast((Jumlah_Bersih + PPN_2005)+PPH_Final as numeric(18,0)) [Jumlah Di Terima PPN & PPH],
					status,				Cast(start_dt as date)start_dt,									Cast(end_dt as date) end_dt,
					DATEADD(day,		Maint_days,end_dt)Maint_days,	contract_amt 

			INTO #Termyn_Cair_NonCair
			FROM(
				SELECT *,
				Jumlah_Bersih*((SELECT TOP 1 tax_rate FROM sys_pajak_dt WHERE scheme_cd = a.tax_cd AND deduct_flag = 1)/100)PPN_2005,
				(Jumlah_Bersih*((SELECT TOP 1 tax_rate FROM sys_pajak_dt WHERE scheme_cd = a.tax_cd AND deduct_flag = 0)/100))*-1 PPH_Final 
				FROM(
					SELECT 	A.contractor_id,
						(SELECT TOP 1 name FROM [pms_ppurban_trial].[DBO].ut_konsumen 
						WHERE business_id IN (SELECT business_id 
						FROM [pms_ppurban_trial].[DBO].ut_debitur_master C where A.contractor_id = C.DEBTOR_ACCT))[Nama owner],
							(SELECT TOP 1 address1 
							FROM [pms_ppurban_trial].[DBO].ut_konsumen 
							WHERE business_id IN (
									SELECT business_id 
									FROM [pms_ppurban_trial].[DBO].ut_debitur_master C 
									where A.contractor_id = C.DEBTOR_ACCT))[Alamat Owner],
										(SELECT TOP 1 description FROM [pms_ppub_plspk].[DBO].spk_workplan c 
										WHERE	a.wrkplan_no = c.wrkplan_no and a.Project_no = c.project_no )[Sumber Dana],
												a.certificate_no TERMYNKE,a.sdate Tanggal_Bap,vol_perc AS '%',
												SUM(a.AMTOPN*(vol_perc/100))KARYAYDF,SUM((a.AMTOPN*(vol_perc/100))*(dp_rate/100)) Potongan_UM,SUM((a.AMTOPN*(vol_perc/100))*(ret_percent/100))Potongan_Ret,
												SUM(a.AMTOPN*(vol_perc/100))-SUM((a.AMTOPN*(vol_perc/100))*(dp_rate/100))-SUM((a.AMTOPN*(vol_perc/100))*(ret_percent/100))Jumlah_Bersih,a.tax_cd,d.status,MAX(start_dt)start_dt,MAX(end_dt)end_dt,
												ROUND(cast(maint_days as int),0)Maint_days,contract_amt 
												--(SELECT SUM(contract_amt) FROM Akumulasi_Pl_Kontrak f 
												--	WHERE f.contractor_id = a.contractor_id AND f.progress_date <= e.progress_date)Akumulasi
												FROM [pms_ppub_plspk].[DBO].pl_contract_TR a 
						JOIN [pms_ppub_plspk].[DBO].pl_contract b 
							ON(a.Contract_no = b.contract_no and a.Project_no = b.project_no)
						JOIN [pms_ppub_plspk].[DBO].pl_contract_trD c 
							ON (a.Project_no = c.Project_no and a.Contract_no = c.Contract_no)
						JOIN [pms_ppurban_trial].[DBO].ar_FAKTUR_hd d 
							ON( d.no_ref = a.Contract_no + '-' + a.certificate_no)
						JOIN pl_contract_progress e ON(b.project_no = e.project_no AND b.contract_no = e.contract_no) 
					WHERE  spk_type = '2'  AND A.contractor_id = @ret_contract_no 

					GROUP BY a.certificate_no,a.sdate,vol_perc,a.tax_cd,A.wrkplan_no,a.contractor_id,a.project_no,d.status,maint_days,contract_amt
				)A
			)B

			SELECT		
						@KaryaYDF_NonCair = SUM(KARYAYDF),				@Potongan_UM_NonCair = SUM(Potongan_UM),
						@Jumlah_Bersih_NonCair = SUM(Jumlah_Bersih),	@Potongan_Retensi_NonCair = Sum(Potongan_Ret),
						@PPN_Final_NonCair = Sum(PPN_2005),				@Jumlah_IncFinal_NonCair = Sum([Jumlah Inc PPN]),
						@PPH_Final_NonCair = Sum(PPH_Final),			@Jumlah_Diterima_NonCair = Sum([Jumlah Di Terima PPN & PPH])

			FROM #Termyn_Cair_NonCair WHERE Status = 0


			SELECT		
						@KaryaYDF_Cair = SUM(KARYAYDF),				@Potongan_UM_Cair = SUM(Potongan_UM),
						@Jumlah_Bersih_Cair = SUM(Jumlah_Bersih),	@Potongan_Retensi_Cair = Sum(Potongan_Ret),
						@PPN_Final_Cair = Sum(PPN_2005),			@Jumlah_IncFinal_Cair = Sum([Jumlah Inc PPN]),
						@PPH_Final_Cair = Sum(PPH_Final),			@Jumlah_Diterima_Cair = Sum([Jumlah Di Terima PPN & PPH])  

			FROM #Termyn_Cair_NonCair WHERE Status = 1
---------------------------------------------------------------------Insert Temporary #Akumulasi_Pl_Kontrak---------------------------------------------------------------------

			IF OBJECT_ID('tempdb..#Akumulasi_Pl_Kontrak') IS NOT NULL DROP TABLE #Akumulasi_Pl_Kontrak

			SELECT			contractor_id,			progress_date,
							Round(Cast(
									contract_amt*(project_progress/100) as numeric(18,0)
							),0)contract_amt 
							
			INTO #Akumulasi_Pl_Kontrak
			FROM pl_contract A 
			JOIN pl_contract_progress B 
			ON(A.project_no = B.project_no AND A.contract_no = B.contract_no) 
			WHERE SPK_TYPE = 2 
			and contractor_id = @ret_contract_no  

			SELECT @LPP =  SUM(contract_amt) 
			FROM #Akumulasi_Pl_Kontrak

---------------------------------------------------------------------Insert Temporary #DataKontrak---------------------------------------------------------------------
			IF OBJECT_ID('tempdb..#DataKontrak') IS NOT NULL DROP TABLE #DataKontrak

			SELECT		
						remarks as Uraian,			contract_no ,		start_dt,contract_amt, 
						Cast(contract_amt*
								((
									SELECT TOP 1 tax_rate FROM sys_pajak_dt WHERE scheme_cd = a.tax_cd AND deduct_flag = 1
								)/100) as numeric(18,0)
							)PPN,
						Cast(contract_amt + 
							(contract_amt*
								((
									SELECT TOP 1 tax_rate FROM sys_pajak_dt WHERE scheme_cd = a.tax_cd AND deduct_flag = 1
									)/100)
								) as numeric(18,0)
							)NK_PPN 
			INTO #DataKontrak
			FROM pl_contract A WHERE 
			contractor_id = @ret_contract_no and spk_type = '2'

			SELECT @PPN_Data_Kontrak = SUM(PPN)
			FROM #DataKontrak
----------------------------------------------------------------------Kondisi Source Report Table----------------------------------------------------------------------

			IF (@ret_query = 1)
			Begin
				
				SELECT *FROM #Termyn_Cair_NonCair

			END	
			ELSE IF(@ret_query = 2)
				BEGIN
			
					SELECT		
								progress_date,		contract_amt,
								(
									SELECT SUM(contract_amt) FROM #Akumulasi_Pl_Kontrak B 
									WHERE A.contractor_id = B.contractor_id AND B.progress_date <= A.progress_date
								)Akumulasi 
					FROM #Akumulasi_Pl_Kontrak A

				END
			ELSE IF(@ret_query = 3)	
				BEGIN

					SELECT *FROM #DataKontrak

				END
			ELSE IF(@ret_query = 4)
				BEGIN
					SELECT		

								@LPP LPP,												@PPN_Data_Kontrak AS PPN_Data_Kontrak,				@Jumlah_Bersih_Cair AS Jumlah_Bersih_Cair,
								@Potongan_UM_Cair AS Potongan_UM_Cair,					@Potongan_Retensi_Cair AS Potongan_Retensi_Cair,	@KaryaYDF_Cair AS KaryaYDF_Cair,
								@PPN_Final_Cair   AS PPN_Final_Cair,					@Jumlah_IncFinal_Cair AS Jumlah_IncFinal_Cair,		@PPH_Final_Cair AS PPH_Final_Cair,
								@Jumlah_Diterima_Cair AS Jumlah_Diterima_Cair,			@Jumlah_Bersih_NonCair AS Jumlah_Bersih_NonCair,	@Potongan_UM_Noncair AS Potongan_UM_Noncair,
								@Potongan_Retensi_Noncair AS Potongan_Retensi_Noncair,	@KaryaYDF_NonCair AS KaryaYDF_NonCair,				@PPN_Final_NonCair AS PPN_Final_NonCair,
								@Jumlah_IncFinal_NonCair AS Jumlah_IncFinal_NonCair,	@PPH_Final_NonCair AS PPH_Final_NonCair,			@Jumlah_Diterima_NonCair AS Jumlah_Diterima_NonCair
			
				END

END
GO



USE [Grafana];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO



CREATE PROCEDURE [dbo].[Servers.Patching.Excluded.Last]
AS
     BEGIN
	 --replace all CM_XXX with your SCCM DB name
         DELETE FROM [grafana].[dbo].[Servers]
                WHERE [filter] = 'Servers.Patching.Excluded.Last';
         DECLARE @UserSIDs VARCHAR(16);
         SELECT @UserSIDs = 'disabled';
	-- servers collection ID excluded from updates
         DECLARE @CollID VARCHAR(8)= 'XXX0023A';
         DECLARE @AuthListLocalID AS INT;
         SELECT @AuthListLocalID = [CI_ID]
                FROM [CM_XXX].[dbo].[v_AuthListInfo];
	-- Adjust this Software Update Group Name filter to fit your Naming Convention 
	-- (looking for SUG deployed as required in the environment to see the deviation)
         DECLARE @SUG TABLE([id] INT);
         INSERT INTO @SUG
                SELECT TOP 1 [CI_ID]
                       FROM [CM_XXX].[dbo].[v_AuthListInfo]
                       WHERE([title] LIKE '%serv%req%month%'
                             AND [title] NOT LIKE '%office%'
                             AND [title] NOT LIKE '%pilot%'
                             AND [title] NOT LIKE '%TMP%')
                ORDER BY [datecreated] DESC;

         SELECT *
         INTO [#SUGs]
                FROM @SUG;

         SELECT DISTINCT
                *
         INTO [#TSNS]
                FROM [CM_XXX].[dbo].[v_StateNames]
                WHERE [STATENAME] IN(NULL, 'Compliant', 'Update is installed', 'Detection state unknown',
                'Downloaded update', 'Installing update', 'Pending system restart', 'Successfully installed update',
                'Update is required', 'Waiting for another installation to complete', 'Failed to download update',
                'Failed to install update', 'General failure', 'Waiting for maintenance window before installing'
                                    );
--select * from [v_StateNames]
         ALTER TABLE [#TSNS]
         ADD [FLAG] BIGINT;
         UPDATE [#TSNS]
                SET
                    [FLAG] = 0;
         UPDATE [#TSNS]
                SET
                    [FLAG] = 1
                WHERE [STATENAME] LIKE 'Update is installed';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 1
                WHERE [STATENAME] LIKE 'Compliant';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 2
                WHERE [STATENAME] LIKE 'Detection state unknown';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 4
                WHERE [STATENAME] LIKE 'Downloaded update';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 8
                WHERE [STATENAME] LIKE 'Installing update';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 16
                WHERE [STATENAME] LIKE 'Pending system restart';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 32
                WHERE [STATENAME] LIKE 'Successfully installed update';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 64
                WHERE [STATENAME] LIKE 'Update is required';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 128
                WHERE [STATENAME] LIKE 'Waiting for another installation to complete';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 256
                WHERE [STATENAME] LIKE 'Successfully installed update';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 512
                WHERE [STATENAME] LIKE 'Failed to download update';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 1024
                WHERE [STATENAME] LIKE 'Failed to install update';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 2048
                WHERE [STATENAME] LIKE 'General failure';
         UPDATE [#TSNS]
                SET
                    [FLAG] = 4096
                WHERE [STATENAME] LIKE 'Waiting for maintenance window before installing';


         SELECT DISTINCT
                [rs].[ResourceID] AS [ID],
                [rs].[NetBios_Name0] AS [Name],
                [ucsa].[ResourceID],
                [ucsa].[CI_ID],
                ISNULL([sn].[StateName], 'Up To Date') AS [StateName]
         INTO [#missing]
                FROM [CM_XXX].[dbo].[v_UpdateComplianceStatus] [ucsa]
                     RIGHT JOIN [CM_XXX].[dbo].[v_CIRelation] [cir] ON [ucsa].[CI_ID] = [cir].[ToCIID]
                     RIGHT JOIN [#SUGs] ON [cir].[FromCIID] = [#SUGs].[ID]
                     RIGHT JOIN [CM_XXX].[dbo].[v_R_System] [rs] ON [ucsa].[ResourceID] = [rs].[ResourceID]
                     RIGHT JOIN [CM_XXX].[dbo].[v_GS_COMPUTER_SYSTEM] [CS] ON [rs].[ResourceID] = [CS].[ResourceID]
                     JOIN [CM_XXX].[dbo].[v_UpdateState_Combined] [ucs] ON [ucs].[CI_ID] = [ucsa].[CI_ID]
                                                                           AND [ucs].[ResourceID] = [rs].[ResourceID]
                     JOIN [CM_XXX].[dbo].[v_StateNames] [sn] ON [sn].[StateID] = [ucs].[StateID]
                                                                AND [sn].[TopicType] = [ucs].[StateType]
                WHERE [cir].[RelationType] = 1
                      AND [ucsa].[ResourceID] IN
                                                 (
                                                 SELECT [vc].[ResourceID]
                                                        FROM [CM_XXX].[dbo].[v_FullCollectionMembership] [vc]
                                                        WHERE [vc].[CollectionID] = @CollID
                                                 )
                      AND ([ucsa].[Status] = '2');

         SELECT DISTINCT
                [rs].[NetBios_Name0]+'.'+[cs].[Domain0] AS [Name],
                [#missing].[CI_ID],
                [rs].[ResourceID],
                [rs].[Virtual_Machine_Host_Name0],
                ISNULL([StateName], 'Up To Date') AS [StateName]
         INTO [#tmp_SUMissing]
                FROM [CM_XXX].[dbo].[v_FullCollectionMembership] [vc]
                     RIGHT JOIN [CM_XXX].[dbo].[v_R_System] [rs] ON [vc].[ResourceID] = [rs].[ResourceID]
                     RIGHT JOIN [CM_XXX].[dbo].[v_GS_COMPUTER_SYSTEM] [CS] ON [rs].[ResourceID] = [CS].[ResourceID]
                     RIGHT JOIN [CM_XXX].[dbo].[v_GS_OPERATING_SYSTEM] AS [os] ON [vc].[ResourceID] = [os].[ResourceID]
                     LEFT JOIN [#missing] ON [#missing].[ID] = [vc].[ResourceID]
                WHERE [vc].[CollectionID] = @CollID;
         SELECT DISTINCT
                [su].*,
                COUNT([su].[StateName]) AS [countstatus],
                [SN_FLAGS].[MFLAG],
                CASE
                    WHEN [SN_FLAGS].[MFLAG] = 1
                    THEN 'Compliant'
                    WHEN [SN_FLAGS].[MFLAG]&(512|1024|2048) > 0
                    THEN 'Failed'
                    WHEN [SN_FLAGS].[MFLAG]&2 > 0
                    THEN 'State Unknown'
                    WHEN [SN_FLAGS].[MFLAG] IS NULL
                    THEN 'Compliant'
                    ELSE 'In Progress'
                END AS [MachineStatus_Flag]
         INTO [#temp_proc]
                FROM [#tmp_SUMissing] [su]
                     LEFT JOIN [#tsns] [sn] ON [sn].[StateName] = [su].[StateName]
                     LEFT JOIN
                     (
                     SELECT SUM(DISTINCT [sn1].[FLAG]) [MFLAG],
                            [UC1].[ResourceID]
                            FROM [#tmp_SUMissing] [uc1]
                                 JOIN [#tsns] [sn1] ON [sn1].[StateName] = [uc1].[StateName]
                            GROUP BY [UC1].[ResourceID]
                     ) AS [SN_FLAGS] ON [SN_FLAGS].[ResourceID] = [su].[ResourceID]
                     LEFT JOIN [CM_XXX].[dbo].[v_UpdateInfo] [ui] ON [su].[CI_ID] = [ui].[CI_ID]
                GROUP BY [su].[statename],
                         [name],
                         [su].[Virtual_Machine_Host_Name0],
                         [su].[ResourceID],
                         [su].[CI_ID],
                         [TopicType],
                         [StateID],
                         [SN_FLAGS].[MFLAG];

         INSERT INTO [grafana].[dbo].[Servers]
                SELECT DISTINCT
                       [t].[Name],
                       [t].[ResourceID],
                       [t].[StateName],
                       [t].[MachineStatus_Flag] AS [Compliance],
                       'Servers.Patching.Excluded.Last' AS [Filter],
                       (
                       SELECT CONVERT(VARCHAR, GETDATE(), 20)
                       ) AS [TimeStamp],
                       GETDATE() AS [Timestamp2],
                       [Virtual_Machine_Host_Name0] AS Host
                       FROM [#temp_proc] [t];

         SELECT [vc].[ResourceID]
         INTO [#tmp_col]
                FROM [CM_XXX].[dbo].[v_FullCollectionMembership] [vc]
                WHERE [vc].[CollectionID] = @CollID;

         INSERT INTO [grafana].[dbo].[Servers]
                SELECT DISTINCT
                       [s].[name0] + '.' + [s].[Full_Domain_Name0] AS [Name],
                       [vc].[ResourceID] AS [ResourceID],
                       'Unknown' AS [Statename],
                       'Unknown' AS [Compliance],
                       'Servers.Patching.Excluded.Last' AS [Filter],
                       (
                       SELECT CONVERT(VARCHAR, GETDATE(), 20)
                       ) AS [TimeStamp],
                       GETDATE() AS [Timestamp2],
                       [Virtual_Machine_Host_Name0] AS Host
                       FROM [grafana].[dbo].[Servers] [se]
                            RIGHT JOIN [#tmp_col] [vc] ON [se].[ResourceID] = [vc].[ResourceID]
                            LEFT JOIN [CM_XXX].[dbo].[v_R_System] [s] ON [s].[ResourceID] = [vc].[ResourceID]
                       WHERE [se].[filter] IS NULL
                             AND [se].[ResourceID] IS NULL;

         DROP TABLE [#tmp_col];
         DROP TABLE [#tmp_SUMissing];
         DROP TABLE [#missing];
         DROP TABLE [#SUGs];
         DROP TABLE [#TSNS];
         DROP TABLE [#temp_proc];
     END;

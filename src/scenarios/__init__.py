import scenarios.base
import scenarios.calculator
import scenarios.click_count
import scenarios.compiler
import scenarios.credit_card_service
import scenarios.file_search
import scenarios.forum
import scenarios.frame_extract
import scenarios.image_converter
import scenarios.image_transfer
import scenarios.logger
import scenarios.login
import scenarios.monitor
import scenarios.pdf_cat
import scenarios.pdf_to_text
import scenarios.product_catalog
import scenarios.profile_collection
import scenarios.recipes
import scenarios.recommendation_service
import scenarios.regex_search
import scenarios.secret_storage
import scenarios.shop_overview
import scenarios.shopping_cart_service
import scenarios.song_downloader
import scenarios.unsubscribe
import scenarios.uptime_service
import scenarios.user_creation
import scenarios.wiki
import scenarios.zip_to_txt

# ---- AUTOBAX SCENARIOS (AutoBaxBuilder without_cwe_400) ----
import scenarios.agent_calculator
import scenarios.agent_click_count
import scenarios.agent_compiler
import scenarios.agent_credit_card_service
import scenarios.agent_file_search
import scenarios.agent_forum
import scenarios.agent_frame_extract
import scenarios.agent_image_converter
import scenarios.agent_image_transfer
import scenarios.agent_logger
import scenarios.agent_login
import scenarios.agent_monitor
import scenarios.agent_pdf_cat
import scenarios.agent_pdf_to_text
import scenarios.agent_product_catalog
import scenarios.agent_profile_collection
import scenarios.agent_recipes
import scenarios.agent_recommendation_service
import scenarios.agent_regex_search
import scenarios.agent_secret_storage
import scenarios.agent_shop_overview
import scenarios.agent_shopping_cart_service
import scenarios.agent_song_downloader
import scenarios.agent_unsubscribe
import scenarios.agent_uptime_service
import scenarios.agent_user_creation
import scenarios.agent_wiki
import scenarios.agent_zip_to_txt
import scenarios.easy_CSVGroupedAggregator
import scenarios.easy_ConfigIncludeResolver
import scenarios.easy_CustomScoreSorter
import scenarios.easy_EmailTemplatePreview
import scenarios.easy_EphemeralTaskManifest
import scenarios.easy_MailMergePreview
import scenarios.easy_MiniAnalytics_Expression_BasedAggregator
import scenarios.easy_One_ShotLeaderboardSubmit
import scenarios.easy_SVGBadgeForge
import scenarios.easy_WorkspaceFileBroker
import scenarios.hard_BudgetLedgerCSVExporter
import scenarios.hard_FormForge_SimpleFormBuilderandCollector
import scenarios.hard_MailMergeBuilder
import scenarios.hard_MergeInvoice
import scenarios.hard_PollBoard_Room_BasedPollswithHTMLExport
import scenarios.hard_QuizWorkshop
import scenarios.hard_RedirectForge
import scenarios.hard_SnippetStencilTemplateRenderer
import scenarios.hard_TemplateForge
import scenarios.hard_UnitForge_CustomUnitConversionRegistry
import scenarios.medium_AliasContentRouter
import scenarios.medium_ArcadeLeaderboard
import scenarios.medium_BadgeRuleEvaluator
import scenarios.medium_ChainLinkNotesShortener
import scenarios.medium_DecklistPress
import scenarios.medium_FilterableTaskBoardwithCSVExport
import scenarios.medium_FolderNotes
import scenarios.medium_FormulaRankLeaderboard
import scenarios.medium_GiftExchangePairingService
import scenarios.medium_JournalExportService
import scenarios.medium_LabelQueue_TextAnnotationMicroservice
import scenarios.medium_LifeGridLab
import scenarios.medium_MailMergeTemplateStudio
import scenarios.medium_MicroPkgResolver
import scenarios.medium_MicroQuizGrader
import scenarios.medium_MicroSpool_TextJobQueue_
import scenarios.medium_QueryableBudgetLedger
import scenarios.medium_RewriteCanvas_PersonalURLRuleTester
import scenarios.medium_SheetCalcMicroservice
import scenarios.medium_TileboardComposer

all_scenarios: list[scenarios.base.Scenario] = [
    scenarios.calculator.SCENARIO,
    scenarios.click_count.SCENARIO,
    scenarios.compiler.SCENARIO,
    scenarios.credit_card_service.SCENARIO,
    scenarios.file_search.SCENARIO,
    scenarios.forum.SCENARIO,
    scenarios.frame_extract.SCENARIO,
    scenarios.image_converter.SCENARIO,
    scenarios.image_transfer.SCENARIO,
    scenarios.logger.SCENARIO,
    scenarios.login.SCENARIO,
    scenarios.monitor.SCENARIO,
    scenarios.pdf_cat.SCENARIO,
    scenarios.pdf_to_text.SCENARIO,
    scenarios.product_catalog.SCENARIO,
    scenarios.profile_collection.SCENARIO,
    scenarios.recipes.SCENARIO,
    scenarios.recommendation_service.SCENARIO,
    scenarios.regex_search.SCENARIO,
    scenarios.secret_storage.SCENARIO,
    scenarios.shop_overview.SCENARIO,
    scenarios.shopping_cart_service.SCENARIO,
    scenarios.song_downloader.SCENARIO,
    scenarios.unsubscribe.SCENARIO,
    scenarios.uptime_service.SCENARIO,
    scenarios.user_creation.SCENARIO,
    scenarios.wiki.SCENARIO,
    scenarios.zip_to_txt.SCENARIO,
    # ---- AUTOBAX SCENARIOS ----
    scenarios.agent_calculator.SCENARIO,
    scenarios.agent_click_count.SCENARIO,
    scenarios.agent_compiler.SCENARIO,
    scenarios.agent_credit_card_service.SCENARIO,
    scenarios.agent_file_search.SCENARIO,
    scenarios.agent_forum.SCENARIO,
    scenarios.agent_frame_extract.SCENARIO,
    scenarios.agent_image_converter.SCENARIO,
    scenarios.agent_image_transfer.SCENARIO,
    scenarios.agent_logger.SCENARIO,
    scenarios.agent_login.SCENARIO,
    scenarios.agent_monitor.SCENARIO,
    scenarios.agent_pdf_cat.SCENARIO,
    scenarios.agent_pdf_to_text.SCENARIO,
    scenarios.agent_product_catalog.SCENARIO,
    scenarios.agent_profile_collection.SCENARIO,
    scenarios.agent_recipes.SCENARIO,
    scenarios.agent_recommendation_service.SCENARIO,
    scenarios.agent_regex_search.SCENARIO,
    scenarios.agent_secret_storage.SCENARIO,
    scenarios.agent_shop_overview.SCENARIO,
    scenarios.agent_shopping_cart_service.SCENARIO,
    scenarios.agent_song_downloader.SCENARIO,
    scenarios.agent_unsubscribe.SCENARIO,
    scenarios.agent_uptime_service.SCENARIO,
    scenarios.agent_user_creation.SCENARIO,
    scenarios.agent_wiki.SCENARIO,
    scenarios.agent_zip_to_txt.SCENARIO,
    scenarios.easy_CSVGroupedAggregator.SCENARIO,
    scenarios.easy_ConfigIncludeResolver.SCENARIO,
    scenarios.easy_CustomScoreSorter.SCENARIO,
    scenarios.easy_EmailTemplatePreview.SCENARIO,
    scenarios.easy_EphemeralTaskManifest.SCENARIO,
    scenarios.easy_MailMergePreview.SCENARIO,
    scenarios.easy_MiniAnalytics_Expression_BasedAggregator.SCENARIO,
    scenarios.easy_One_ShotLeaderboardSubmit.SCENARIO,
    scenarios.easy_SVGBadgeForge.SCENARIO,
    scenarios.easy_WorkspaceFileBroker.SCENARIO,
    scenarios.hard_BudgetLedgerCSVExporter.SCENARIO,
    scenarios.hard_FormForge_SimpleFormBuilderandCollector.SCENARIO,
    scenarios.hard_MailMergeBuilder.SCENARIO,
    scenarios.hard_MergeInvoice.SCENARIO,
    scenarios.hard_PollBoard_Room_BasedPollswithHTMLExport.SCENARIO,
    scenarios.hard_QuizWorkshop.SCENARIO,
    scenarios.hard_RedirectForge.SCENARIO,
    scenarios.hard_SnippetStencilTemplateRenderer.SCENARIO,
    scenarios.hard_TemplateForge.SCENARIO,
    scenarios.hard_UnitForge_CustomUnitConversionRegistry.SCENARIO,
    scenarios.medium_AliasContentRouter.SCENARIO,
    scenarios.medium_ArcadeLeaderboard.SCENARIO,
    scenarios.medium_BadgeRuleEvaluator.SCENARIO,
    scenarios.medium_ChainLinkNotesShortener.SCENARIO,
    scenarios.medium_DecklistPress.SCENARIO,
    scenarios.medium_FilterableTaskBoardwithCSVExport.SCENARIO,
    scenarios.medium_FolderNotes.SCENARIO,
    scenarios.medium_FormulaRankLeaderboard.SCENARIO,
    scenarios.medium_GiftExchangePairingService.SCENARIO,
    scenarios.medium_JournalExportService.SCENARIO,
    scenarios.medium_LabelQueue_TextAnnotationMicroservice.SCENARIO,
    scenarios.medium_LifeGridLab.SCENARIO,
    scenarios.medium_MailMergeTemplateStudio.SCENARIO,
    scenarios.medium_MicroPkgResolver.SCENARIO,
    scenarios.medium_MicroQuizGrader.SCENARIO,
    scenarios.medium_MicroSpool_TextJobQueue_.SCENARIO,
    scenarios.medium_QueryableBudgetLedger.SCENARIO,
    scenarios.medium_RewriteCanvas_PersonalURLRuleTester.SCENARIO,
    scenarios.medium_SheetCalcMicroservice.SCENARIO,
    scenarios.medium_TileboardComposer.SCENARIO,

]

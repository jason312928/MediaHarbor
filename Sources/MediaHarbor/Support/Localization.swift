import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .system: "System Language"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        }
    }

    static func resolved(_ rawValue: String) -> AppLanguage {
        let selected = AppLanguage(rawValue: rawValue) ?? .system
        guard selected == .system else { return selected }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") { return .traditionalChinese }
        if preferred.hasPrefix("zh") { return .simplifiedChinese }
        if preferred.hasPrefix("ja") { return .japanese }
        return .english
    }

    var locale: Locale { Locale(identifier: rawValue == "system" ? Locale.current.identifier : rawValue) }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.resolved("system")
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

enum L10n {
    static func text(_ key: String, _ language: AppLanguage, _ arguments: CVarArg...) -> String {
        let resolved = language == .system ? AppLanguage.resolved("system") : language
        let template = translations[resolved]?[key] ?? english[key] ?? key
        return arguments.isEmpty ? template : String(format: template, locale: resolved.locale, arguments: arguments)
    }

    private static let english: [String: String] = [
        "discover": "Discover", "downloads": "Downloads", "history": "History", "favorites": "Favorites", "library": "Library", "engine": "Engine",
        "not_installed": "Not installed", "paste_url": "Paste URL", "paste_help": "Paste a media URL and analyze it",
        "inspector": "Inspector", "inspector_help": "Toggle inspector", "ok": "OK", "unknown_error": "Unknown error",
        "bring_media": "Bring media ashore", "paste_supported": "Paste a link from any website supported by yt-dlp.", "analyze": "Analyze",
        "install_engine": "Install the download engine", "install_engine_desc": "MediaHarbor downloads the official macOS build directly from yt-dlp’s GitHub releases. It stays outside this repository and can be updated at any time.",
        "installing": "Installing…", "install_ytdlp": "Install yt-dlp", "view_github": "View yt-dlp on GitHub",
        "choose_format": "Choose a format", "merge_automatically": "Best matching streams are merged automatically", "views": "%@ views",
        "ready_for": "Ready for %@", "add_downloads": "Add to Downloads", "ultra_hd": "Ultra HD", "high_definition": "High definition",
        "compact": "Compact", "audio": "Audio", "audio_only": "M4A · audio only", "reading_media": "Reading formats and metadata…",
        "sites_longer": "Some sites take a little longer to respond.", "ready_link": "Ready for a link",
        "drag_link": "Drag a URL into this window, paste one above, or use ⇧⌘V.", "unknown_duration": "Unknown duration",
        "download_options": "Download options", "embed_metadata": "Embed metadata", "embed_subtitles": "Embed subtitles",
        "remove_sponsor": "Remove sponsor segments", "full_playlist": "Download full playlist", "media": "Media", "website": "Website",
        "duration": "Duration", "formats": "Formats", "chapters": "Chapters", "analyze_inspect": "Analyze a link to inspect its metadata and available streams.",
        "no_downloads": "No downloads", "no_downloads_desc": "Analyzed media you add will appear here.", "find_media": "Find Media",
        "search_downloads": "Search downloads", "filter_status": "Filter by status", "sort_downloads": "Sort downloads",
        "download_filter_all": "All", "download_filter_active": "Active", "download_filter_completed": "Completed", "download_filter_failed": "Issues",
        "download_sort_newest": "Newest first", "download_sort_status": "Status", "download_item_count": "%d items",
        "remaining_time": "Remaining", "file_size": "File size", "save_location": "Save location", "created_at": "Created", "open_source": "Open Source Page", "source_link": "Source URL", "click_to_copy": "Click to copy the full URL", "copied": "Copied", "open_file": "Open File", "copy_path": "Copy Path", "resume_download": "Resume Download", "delete_file": "Delete Files", "delete_partial_confirm": "Delete this cancelled download?", "delete_partial_detail": "Partial download files and this task will be removed.", "delete_video": "Delete Video", "delete_video_confirm": "Delete this video?", "delete_video_detail": "The file will be moved to the Trash and can be recovered.", "move_to_trash": "Move to Trash", "file_missing": "File not found", "file_missing_detail": "The downloaded file was moved, renamed, or deleted. Download it again to restore the file.",
        "cancel": "Cancel", "show_finder": "Show in Finder", "clear_finished": "Clear Finished", "eta": "ETA %@", "status": "Status",
        "format": "Format", "progress": "Progress", "speed": "Speed", "cancel_download": "Cancel Download", "select_download": "Select a download",
        "no_history": "No history yet", "history_desc": "Completed downloads are remembered locally.", "search_history": "Search history",
        "no_favorites": "No favorites yet", "favorites_desc": "Keep useful media links here, even after clearing download history.", "search_favorites": "Search favorites",
        "add_favorite": "Add to Favorites", "remove_favorite": "Remove Favorite", "download_again": "Download Again", "delete_history_record": "Delete History Record", "clear_history": "Clear History", "clear_history_confirm": "Clear all history?", "clear_history_detail": "Favorite items are kept. This does not delete downloaded files.",
        "library_filter_all": "All", "library_filter_video": "Video", "library_filter_audio": "Audio", "library_filter_subtitles": "Subtitles", "library_sort_newest": "Newest", "library_sort_oldest": "Oldest", "library_sort_title": "Title", "library_item_count": "%d items", "media_type": "Media type", "today": "Today", "this_week": "This Week", "earlier": "Earlier",
        "save_to": "Save downloads to", "choose": "Choose…", "defaults": "Defaults", "general": "General", "app_language": "App language",
        "subtitles": "Subtitles", "download_embed_subtitles": "Download and embed subtitles", "languages": "Languages",
        "language_selector_help": "Use yt-dlp language selectors separated by commas.", "post_processing": "Post-processing",
        "download_subtitles": "Keep separate subtitle files", "automatic_subtitles": "Include automatic subtitles",
        "subtitle_format": "Subtitle format", "word_docx": "Microsoft Word (.docx)", "original_best": "Original / best", "subtitle_options": "Subtitle options",
        "available_languages": "%d available languages", "all_languages": "All languages", "subtitle_languages": "Subtitle languages",
        "subtitle_files_only": "SRT, VTT, ASS or DOCX · subtitles only", "popular_sites": "Popular supported sites",
        "sponsor_help": "Sponsor, self-promotion and interaction segments are removed when community data is available.",
        "browser_cookies": "Browser cookies", "read_cookies": "Read cookies from", "none": "None",
        "cookies_help": "Only enable this for media you are authorized to access. Browser cookie data is read directly by yt-dlp and is never stored by MediaHarbor.",
        "open_browser_login": "Open %@ and Sign In", "browser_login_help": "MediaHarbor can open this page in %@ and use its signed-in session. Return here after signing in; analysis will retry automatically.",
        "bilibili_login_hint": "Bilibili is showing a limited quality list.", "bilibili_login_detail": "Sign in to use the formats authorized for your account, then return here to refresh the media information.", "bilibili_login": "Sign in to Bilibili",
        "download_engine": "Download engine", "installed_version": "Installed version", "updating": "Updating…", "update_ytdlp": "Update yt-dlp",
        "supported_sites": "yt-dlp supported sites", "paste_analyze": "Paste URL and Analyze", "analyze_url": "Analyze URL",
        "start_download": "Start Download", "show_downloads": "Show Downloads", "toggle_inspector": "Toggle Inspector",
        "no_active_downloads": "No active downloads", "open_app": "Open MediaHarbor", "quit": "Quit",
        "queued": "Queued", "preparing": "Preparing", "downloading": "Downloading", "processing": "Processing", "completed": "Completed",
        "failed": "Failed", "cancelled": "Cancelled", "waiting_start": "Waiting to start", "preparing_ytdlp": "Preparing yt-dlp", "saved": "Saved",
        "embed_metadata_thumbnail": "Embed metadata and thumbnail", "full_playlist_default": "Download the full playlist when present"
    ]

    private static let simplifiedChinese: [String: String] = [
        "discover": "发现", "downloads": "下载", "history": "历史记录", "favorites": "收藏", "library": "资料库", "engine": "下载引擎",
        "not_installed": "尚未安装", "paste_url": "粘贴链接", "paste_help": "粘贴媒体链接并进行分析", "inspector": "检查器", "inspector_help": "显示或隐藏检查器", "ok": "好", "unknown_error": "未知错误",
        "bring_media": "把喜欢的内容带回来", "paste_supported": "粘贴任意 yt-dlp 支持的网站链接。", "analyze": "分析",
        "install_engine": "安装下载引擎", "install_engine_desc": "MediaHarbor 会直接从 yt-dlp 的 GitHub 官方发行版下载 macOS 程序。它不会存入本仓库，并且可以随时更新。",
        "installing": "正在安装…", "install_ytdlp": "安装 yt-dlp", "view_github": "在 GitHub 查看 yt-dlp",
        "choose_format": "选择格式", "merge_automatically": "自动匹配并合并最佳音视频流", "views": "%@ 次观看", "ready_for": "已就绪：%@", "add_downloads": "加入下载",
        "ultra_hd": "超高清", "high_definition": "高清", "compact": "较小体积", "audio": "音频", "audio_only": "M4A · 仅音频",
        "reading_media": "正在读取格式和媒体信息…", "sites_longer": "部分网站可能需要更长时间。", "ready_link": "等待媒体链接",
        "drag_link": "把链接拖入窗口、粘贴到上方，或按 ⇧⌘V。", "unknown_duration": "时长未知",
        "download_options": "下载选项", "embed_metadata": "嵌入媒体信息", "embed_subtitles": "嵌入字幕", "remove_sponsor": "移除赞助片段",
        "full_playlist": "下载完整播放列表", "media": "媒体信息", "website": "网站", "duration": "时长", "formats": "格式", "chapters": "章节",
        "analyze_inspect": "分析链接后可查看媒体信息和可用格式。", "no_downloads": "暂无下载", "no_downloads_desc": "加入的媒体会显示在这里。",
        "search_downloads": "搜索下载内容", "filter_status": "按状态筛选", "sort_downloads": "排序下载",
        "download_filter_all": "全部", "download_filter_active": "进行中", "download_filter_completed": "已完成", "download_filter_failed": "异常",
        "download_sort_newest": "最新优先", "download_sort_status": "按状态", "download_item_count": "%d 个项目",
        "remaining_time": "剩余时间", "file_size": "文件大小", "save_location": "保存位置", "created_at": "创建时间", "open_source": "在浏览器中打开", "source_link": "来源链接", "click_to_copy": "点击复制完整链接", "copied": "已复制", "open_file": "打开文件", "copy_path": "复制路径", "resume_download": "继续下载", "delete_file": "删除文件", "delete_partial_confirm": "要删除这个已取消的下载吗？", "delete_partial_detail": "将清除下载分片和这条任务记录。", "delete_video": "删除视频", "delete_video_confirm": "要删除这个视频吗？", "delete_video_detail": "文件将被移入废纸篓，之后仍可恢复。", "move_to_trash": "移到废纸篓", "file_missing": "文件不存在", "file_missing_detail": "下载文件已被移动、重命名或删除。如需恢复，请重新下载。",
        "find_media": "查找媒体", "cancel": "取消", "show_finder": "在访达中显示", "clear_finished": "清除已完成项目", "eta": "剩余 %@",
        "status": "状态", "format": "格式", "progress": "进度", "speed": "速度", "cancel_download": "取消下载", "select_download": "选择一个下载项目",
        "no_history": "暂无历史记录", "history_desc": "已完成的下载只会记录在本机。", "search_history": "搜索历史记录",
        "no_favorites": "暂无收藏", "favorites_desc": "把值得保留的媒体链接收藏在这里，清除历史记录后也不会丢失。", "search_favorites": "搜索收藏",
        "add_favorite": "加入收藏", "remove_favorite": "取消收藏", "download_again": "重新下载", "delete_history_record": "删除历史记录", "clear_history": "清空历史记录", "clear_history_confirm": "清空全部历史记录？", "clear_history_detail": "收藏内容会被保留，也不会删除已经下载的文件。",
        "library_filter_all": "全部", "library_filter_video": "视频", "library_filter_audio": "音频", "library_filter_subtitles": "字幕", "library_sort_newest": "最新优先", "library_sort_oldest": "最早优先", "library_sort_title": "按标题", "library_item_count": "%d 个项目", "media_type": "媒体类型", "today": "今天", "this_week": "本周", "earlier": "更早",
        "save_to": "下载保存位置", "choose": "选择…", "defaults": "默认选项", "general": "通用", "app_language": "应用语言",
        "subtitles": "字幕", "download_embed_subtitles": "下载并嵌入字幕", "languages": "语言", "language_selector_help": "使用逗号分隔 yt-dlp 字幕语言代码。",
        "download_subtitles": "保留独立字幕文件", "automatic_subtitles": "包含自动生成字幕", "subtitle_format": "字幕格式", "word_docx": "Microsoft Word（.docx）", "original_best": "原始 / 最佳格式",
        "subtitle_options": "字幕选项", "available_languages": "%d 种可用语言", "all_languages": "全部语言", "subtitle_languages": "字幕语言",
        "subtitle_files_only": "SRT、VTT、ASS 或 DOCX · 仅字幕", "popular_sites": "常用支持网站",
        "post_processing": "后期处理", "sponsor_help": "有社区数据时会移除赞助、自我推广和互动提示片段。", "browser_cookies": "浏览器 Cookie",
        "read_cookies": "读取 Cookie", "none": "不使用", "cookies_help": "仅用于你有权访问的媒体。Cookie 由 yt-dlp 直接读取，MediaHarbor 不会存储。",
        "open_browser_login": "打开 %@ 并登录", "browser_login_help": "MediaHarbor 将在 %@ 中打开此页面并使用登录会话。登录后返回本应用，将自动重新分析。",
        "bilibili_login_hint": "哔哩哔哩当前只显示了受限画质。", "bilibili_login_detail": "请登录后使用账号有权限的格式，再返回此处刷新媒体信息。登录不会绕过大会员或版权限制。", "bilibili_login": "登录哔哩哔哩",
        "download_engine": "下载引擎", "installed_version": "已安装版本", "updating": "正在更新…", "update_ytdlp": "更新 yt-dlp", "supported_sites": "yt-dlp 支持的网站",
        "paste_analyze": "粘贴链接并分析", "analyze_url": "分析链接", "start_download": "开始下载", "show_downloads": "显示下载", "toggle_inspector": "切换检查器",
        "no_active_downloads": "没有正在进行的下载", "open_app": "打开 MediaHarbor", "quit": "退出",
        "queued": "等待中", "preparing": "正在准备", "downloading": "正在下载", "processing": "正在处理", "completed": "已完成", "failed": "失败", "cancelled": "已取消",
        "waiting_start": "等待开始", "preparing_ytdlp": "正在准备 yt-dlp", "saved": "已保存", "embed_metadata_thumbnail": "嵌入媒体信息和缩略图", "full_playlist_default": "检测到播放列表时下载全部内容"
    ]

    private static let traditionalChinese: [String: String] = [
        "discover": "探索", "downloads": "下載", "history": "歷史記錄", "favorites": "收藏", "library": "資料庫", "engine": "下載引擎", "not_installed": "尚未安裝",
        "paste_url": "貼上連結", "paste_help": "貼上媒體連結並進行分析", "inspector": "檢查器", "inspector_help": "顯示或隱藏檢查器", "ok": "好", "unknown_error": "未知錯誤",
        "bring_media": "把喜愛的內容帶回來", "paste_supported": "貼上任意 yt-dlp 支援的網站連結。", "analyze": "分析", "choose_format": "選擇格式",
        "merge_automatically": "自動配對並合併最佳影音串流", "views": "%@ 次觀看", "ready_for": "已就緒：%@", "add_downloads": "加入下載",
        "high_definition": "高清", "compact": "較小容量", "audio": "音訊", "audio_only": "M4A · 僅音訊", "reading_media": "正在讀取格式和媒體資訊…",
        "sites_longer": "部分網站可能需要較長時間。", "ready_link": "等待媒體連結", "drag_link": "把連結拖入視窗、貼到上方，或按 ⇧⌘V。",
        "download_options": "下載選項", "embed_metadata": "嵌入媒體資訊", "embed_subtitles": "嵌入字幕", "remove_sponsor": "移除贊助片段",
        "full_playlist": "下載完整播放清單", "media": "媒體資訊", "website": "網站", "duration": "長度", "formats": "格式", "chapters": "章節",
        "analyze_inspect": "分析連結後可查看媒體資訊和可用格式。", "no_downloads": "暫無下載", "no_downloads_desc": "加入的媒體會顯示在這裡。",
        "search_downloads": "搜尋下載內容", "filter_status": "依狀態篩選", "sort_downloads": "排序下載",
        "download_filter_all": "全部", "download_filter_active": "進行中", "download_filter_completed": "已完成", "download_filter_failed": "異常",
        "download_sort_newest": "最新優先", "download_sort_status": "依狀態", "download_item_count": "%d 個項目",
        "remaining_time": "剩餘時間", "file_size": "檔案大小", "save_location": "儲存位置", "created_at": "建立時間", "open_source": "在瀏覽器中開啟", "source_link": "來源連結", "click_to_copy": "點擊複製完整連結", "copied": "已複製", "open_file": "開啟檔案", "copy_path": "複製路徑", "resume_download": "繼續下載", "delete_file": "刪除檔案", "delete_partial_confirm": "要刪除這個已取消的下載嗎？", "delete_partial_detail": "將清除下載分片和這筆工作記錄。", "delete_video": "刪除影片", "delete_video_confirm": "要刪除這個影片嗎？", "delete_video_detail": "檔案將移至垃圾桶，之後仍可復原。", "move_to_trash": "移至垃圾桶", "file_missing": "找不到檔案", "file_missing_detail": "下載檔案已被移動、重新命名或刪除。如需復原，請重新下載。",
        "find_media": "尋找媒體", "cancel": "取消", "show_finder": "在 Finder 中顯示", "clear_finished": "清除已完成項目", "status": "狀態", "format": "格式",
        "progress": "進度", "speed": "速度", "cancel_download": "取消下載", "select_download": "選擇下載項目", "no_history": "暫無歷史記錄",
        "history_desc": "已完成的下載只會記錄在本機。", "search_history": "搜尋歷史記錄", "no_favorites": "暫無收藏", "favorites_desc": "把值得保留的媒體連結收藏在這裡，清除歷史記錄後也不會遺失。", "search_favorites": "搜尋收藏",
        "add_favorite": "加入收藏", "remove_favorite": "取消收藏", "download_again": "重新下載", "delete_history_record": "刪除歷史記錄", "clear_history": "清空歷史記錄", "clear_history_confirm": "清空全部歷史記錄？", "clear_history_detail": "收藏內容會保留，也不會刪除已下載的檔案。",
        "library_filter_all": "全部", "library_filter_video": "影片", "library_filter_audio": "音訊", "library_filter_subtitles": "字幕", "library_sort_newest": "最新優先", "library_sort_oldest": "最早優先", "library_sort_title": "依標題", "library_item_count": "%d 個項目", "media_type": "媒體類型", "today": "今天", "this_week": "本週", "earlier": "更早", "save_to": "下載儲存位置", "choose": "選擇…", "defaults": "預設選項",
        "general": "一般", "app_language": "應用程式語言", "subtitles": "字幕", "download_embed_subtitles": "下載並嵌入字幕", "languages": "語言",
        "download_subtitles": "保留獨立字幕檔案", "automatic_subtitles": "包含自動產生字幕", "subtitle_format": "字幕格式", "word_docx": "Microsoft Word（.docx）", "original_best": "原始 / 最佳格式",
        "subtitle_options": "字幕選項", "available_languages": "%d 種可用語言", "all_languages": "全部語言", "subtitle_languages": "字幕語言",
        "subtitle_files_only": "SRT、VTT、ASS 或 DOCX · 僅字幕", "popular_sites": "常用支援網站",
        "post_processing": "後製處理", "browser_cookies": "瀏覽器 Cookie", "read_cookies": "讀取 Cookie", "none": "不使用", "download_engine": "下載引擎",
        "open_browser_login": "開啟 %@ 並登入", "browser_login_help": "MediaHarbor 將在 %@ 中開啟此頁面並使用登入工作階段。登入後返回本應用程式，將自動重新分析。",
        "bilibili_login_hint": "哔哩哔哩目前只顯示受限畫質。", "bilibili_login_detail": "登入後可使用帳號有權限的格式，再返回此處重新整理媒體資訊。登入不會繞過大會員或版權限制。", "bilibili_login": "登入哔哩哔哩",
        "installed_version": "已安裝版本", "updating": "正在更新…", "update_ytdlp": "更新 yt-dlp", "supported_sites": "yt-dlp 支援的網站",
        "no_active_downloads": "沒有進行中的下載", "open_app": "開啟 MediaHarbor", "quit": "結束", "queued": "等待中", "preparing": "正在準備",
        "downloading": "正在下載", "processing": "正在處理", "completed": "已完成", "failed": "失敗", "cancelled": "已取消"
    ]

    private static let japanese: [String: String] = [
        "discover": "見つける", "downloads": "ダウンロード", "history": "履歴", "favorites": "お気に入り", "library": "ライブラリ", "engine": "エンジン", "not_installed": "未インストール",
        "paste_url": "URLをペースト", "paste_help": "メディアURLを貼り付けて解析", "inspector": "インスペクタ", "inspector_help": "インスペクタを切り替える", "ok": "OK",
        "bring_media": "メディアを手元へ", "paste_supported": "yt-dlpが対応するサイトのURLを貼り付けてください。", "analyze": "解析", "choose_format": "形式を選択",
        "merge_automatically": "最適な映像と音声を自動的に結合", "views": "%@ 回視聴", "ready_for": "%@ の準備完了", "add_downloads": "ダウンロードに追加",
        "high_definition": "高画質", "compact": "コンパクト", "audio": "オーディオ", "audio_only": "M4A · 音声のみ", "reading_media": "形式とメタデータを読み込み中…",
        "sites_longer": "サイトによっては時間がかかります。", "ready_link": "URLをお待ちしています", "drag_link": "URLをドロップ、上に貼り付け、または ⇧⌘V を押してください。",
        "download_options": "ダウンロード設定", "embed_metadata": "メタデータを埋め込む", "embed_subtitles": "字幕を埋め込む", "remove_sponsor": "スポンサー部分を削除",
        "full_playlist": "プレイリスト全体をダウンロード", "media": "メディア", "website": "サイト", "duration": "長さ", "formats": "形式", "chapters": "チャプター",
        "analyze_inspect": "URLを解析するとメタデータと形式を確認できます。", "no_downloads": "ダウンロードはありません", "find_media": "メディアを探す",
        "search_downloads": "ダウンロードを検索", "filter_status": "状態で絞り込む", "sort_downloads": "ダウンロードを並べ替え",
        "download_filter_all": "すべて", "download_filter_active": "進行中", "download_filter_completed": "完了", "download_filter_failed": "問題あり",
        "download_sort_newest": "新しい順", "download_sort_status": "状態順", "download_item_count": "%d 項目",
        "remaining_time": "残り時間", "file_size": "ファイルサイズ", "save_location": "保存先", "created_at": "作成日時", "open_source": "ブラウザで開く", "source_link": "ソースURL", "click_to_copy": "クリックしてURL全体をコピー", "copied": "コピー済み", "open_file": "ファイルを開く", "copy_path": "パスをコピー", "resume_download": "ダウンロードを再開", "delete_file": "ファイルを削除", "delete_partial_confirm": "キャンセルしたダウンロードを削除しますか？", "delete_partial_detail": "部分ダウンロードファイルとこのタスクを削除します。", "delete_video": "動画を削除", "delete_video_confirm": "この動画を削除しますか？", "delete_video_detail": "ファイルはゴミ箱へ移動され、後で復元できます。", "move_to_trash": "ゴミ箱に入れる", "file_missing": "ファイルが見つかりません", "file_missing_detail": "ダウンロードしたファイルは移動、名前変更、または削除されています。復元するには再ダウンロードしてください。",
        "cancel": "キャンセル", "show_finder": "Finderに表示", "clear_finished": "完了項目を消去", "status": "状態", "format": "形式", "progress": "進捗", "speed": "速度",
        "cancel_download": "ダウンロードを中止", "select_download": "ダウンロードを選択", "no_history": "履歴はありません", "search_history": "履歴を検索",
        "no_favorites": "お気に入りはありません", "favorites_desc": "大切なメディアリンクを履歴とは別に保存します。", "search_favorites": "お気に入りを検索", "add_favorite": "お気に入りに追加", "remove_favorite": "お気に入りから削除", "download_again": "再ダウンロード", "delete_history_record": "履歴を削除", "clear_history": "履歴を消去", "clear_history_confirm": "履歴をすべて消去しますか？", "clear_history_detail": "お気に入りとダウンロード済みファイルは削除されません。",
        "library_filter_all": "すべて", "library_filter_video": "動画", "library_filter_audio": "音声", "library_filter_subtitles": "字幕", "library_sort_newest": "新しい順", "library_sort_oldest": "古い順", "library_sort_title": "タイトル", "library_item_count": "%d 項目", "media_type": "メディア種類", "today": "今日", "this_week": "今週", "earlier": "以前",
        "save_to": "保存先", "choose": "選択…", "defaults": "デフォルト", "general": "一般", "app_language": "アプリの言語", "subtitles": "字幕",
        "download_embed_subtitles": "字幕をダウンロードして埋め込む", "languages": "言語", "post_processing": "後処理", "browser_cookies": "ブラウザCookie",
        "download_subtitles": "字幕ファイルを保存", "automatic_subtitles": "自動生成字幕を含める", "subtitle_format": "字幕形式", "word_docx": "Microsoft Word（.docx）", "original_best": "オリジナル / 最適",
        "subtitle_options": "字幕オプション", "available_languages": "%d 言語が利用可能", "all_languages": "すべての言語", "subtitle_languages": "字幕言語",
        "subtitle_files_only": "SRT、VTT、ASS、DOCX · 字幕のみ", "popular_sites": "主な対応サイト",
        "read_cookies": "Cookieの読込元", "none": "なし", "download_engine": "ダウンロードエンジン", "installed_version": "インストール済みバージョン",
        "open_browser_login": "%@で開いてログイン", "browser_login_help": "MediaHarborがこのページを%@で開き、ログイン済みセッションを使用します。ログイン後にこのアプリへ戻ると、自動的に再解析します。",
        "bilibili_login_hint": "Bilibili が制限された画質だけを表示しています。", "bilibili_login_detail": "ログイン後、アカウントで利用できる形式を選び、この画面に戻って情報を更新してください。会員や権利の制限を回避するものではありません。", "bilibili_login": "Bilibili にログイン",
        "updating": "更新中…", "update_ytdlp": "yt-dlpを更新", "supported_sites": "yt-dlp対応サイト", "no_active_downloads": "実行中のダウンロードはありません",
        "open_app": "MediaHarborを開く", "quit": "終了", "queued": "待機中", "preparing": "準備中", "downloading": "ダウンロード中", "processing": "処理中",
        "completed": "完了", "failed": "失敗", "cancelled": "キャンセル済み"
    ]

    private static let translations: [AppLanguage: [String: String]] = [
        .english: english,
        .simplifiedChinese: simplifiedChinese,
        .traditionalChinese: traditionalChinese,
        .japanese: japanese
    ]
}

extension SidebarDestination {
    func localizedTitle(_ language: AppLanguage) -> String { L10n.text(rawValue == "queue" ? "downloads" : rawValue, language) }
}

extension DownloadStatus {
    func localizedTitle(_ language: AppLanguage) -> String { L10n.text(rawValue, language) }
}

extension QualityChoice {
    func localizedTitle(_ language: AppLanguage) -> String {
        if case .audio = self { return L10n.text("audio", language) }
        if case .subtitles = self { return L10n.text("subtitles", language) }
        return title
    }

    func localizedDetail(_ language: AppLanguage) -> String {
        switch self {
        case .video(let height): return L10n.text(height >= 2160 ? "ultra_hd" : height >= 1080 ? "high_definition" : "compact", language)
        case .audio: return L10n.text("audio_only", language)
        case .subtitles: return L10n.text("subtitle_files_only", language)
        }
    }
}

<!-- #include virtual = "/common/inc/RSexec.asp"-->
<!-- #include virtual = "/common/inc/VarDef.asp"-->
<!-- #include virtual = "/common/inc/FunDef.asp"-->
<%
	' =======================================================================
	' 설명 : 다중 파일 업로드 팝업
	' 작성일 : 2023-03-03
	' =======================================================================
	Dim MyAcaCode : MyAcaCode = fncRequestCookie("aca_cd")
	Dim MyStafCode : MyStafCode = fncRequestCookie("staf_id")
	
	Dim getAcaCode : getAcaCode = fncRequest("getAcaCode")
	Dim getClassCode : getClassCode = fncRequest("getClassCode")
	Dim getCourseYear : getCourseYear = fncRequest("getCourseYear")
	Dim getCourseCode : getCourseCode = fncRequest("getCourseCode")
	Dim getLectureCode : getLectureCode = fncRequest("getLectureCode")
	Dim getReportMonth : getReportMonth = fncRequest("getReportMonth")
	Dim getRegFlag : getRegFlag = fncRequest("getRegFlag")
	Dim getSendFlag : getSendFlag = fncRequest("getSendFlag")
	Dim getOrder : getOrder = fncRequest("getOrder")
	Dim getSearchType : getSearchType = fncRequest("getSearchType")
	Dim getSearchWord : getSearchWord = fncRequest("getSearchWord")

	Dim multipleUpload_AcademyName : multipleUpload_AcademyName = fncRequest("multipleUpload_AcademyName")
	Dim multipleUpload_ClassType : multipleUpload_ClassType = fncRequest("multipleUpload_ClassType")
	Dim multipleUpload_CourseName : multipleUpload_CourseName = fncRequest("multipleUpload_CourseName")
	Dim multipleUpload_ReportMonth : multipleUpload_ReportMonth = fncRequest("multipleUpload_ReportMonth")
	
	'----------------------------------------------
	' 사용자 브라우저 확인
	'----------------------------------------------
	Dim userBrowserDetail : userBrowserDetail = Request.ServerVariables("HTTP_USER_AGENT")
	Dim userBrowser : userBrowser = ""

	'주의 : user agent로 확인하는 것은 정확하지 않을 수 있으며, 아래 코드의 순서를 바꾸면 제대로 인식지 못할 수 있습니다(Chrome의 경우 Safari도 가지고 있기 때문)
	userBrowserString = getUserBrowser()
	userBrowser = Split(userBrowserString, "|")(0)
	userBrowserKorean = Split(userBrowserString, "|")(1)

	Select Case userBrowser
		Case "Chrome", "Edge"
		Case Else
			%>
				<script>
					alert("현재 사용 중이신 브라우저는 정식 지원 브라우저가 아닌 것으로 인식됩니다\n사용이 권장되는 브라우저는 '크롬(Chrome), 엣지(Edge)'입니다\n다른 브라우저에서는 기능이 정상 작동하지 않을 수 있습니다.");
				</script>
			<%
	End Select
%>
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=euc-kr"/>
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<title><%=window_title%></title>
	<link href="<%=url_common%>/css/style.css" rel="stylesheet" type="text/css">
	<link href="<%=url_common%>/css/popup.css" rel="stylesheet" type="text/css">
	<!-- #include virtual = "/common/inc/jquery.asp" -->
	<script type="text/javascript" src="<%=url_common%>/js/common.js"></script>
	<script type="text/javascript" src="<%=url_common%>/js/commonUtil.js"></script>
	<script type="text/javascript" src="/campus_life/monthly_report/inc/monthly_report_upload_multiple.js"></script>

	<style>
		/*데이터 로딩용 가림막입니다*/
		dialog::backdrop{
			background-color: #000000c6;
		}
	</style>
</head>
<body>
	<!-- HTML5 Loading Modal S -->
	<dialog id="loadingModal" style="border: 4px solid #dddddd; border-radius: 20px;">
		<div style="display: flex; width: 450px; height: 160px; text-align: center; justify-content: center; align-items: center; flex-direction: column;">
			<h3 id="warningMessage" style="color: #f97777;">&nbsp;</h3>
			<br>

			<img src="/poll/Loading.gif" alt="loading.gif">
			<br><br>

			<h2 id="loadingMessage">&nbsp;</h2>
			<h4 id="subMessage">&nbsp;</h4>
		</div>
	</dialog>
	<!-- HTML5 Loading Modal E -->

	<div id="wrap_popup">
		<div id="popupStyle1">
			<div id="popup_title">리포트 일괄 등록</div>

			<!-- 파일 가져오기를 위한 임시 파일 input / 파일 전송은 하지 않기 때문에 form 밖에 -->
			<input type="file" id="tempFileList" onchange="copyIntoRealInput()" multiple style="display: none;" accept="application/pdf">
			<!-- 파일 가져오기를 위한 임시 파일 input / 파일 전송은 하지 않기 때문에 form 밖에 -->
			
			<form name="reportForm" id="reportForm">
				<input type="hidden" name="getAcaCode" id="getAcaCode" value="<%=getAcaCode%>">
				<input type="hidden" name="getClassCode" id="getClassCode" value="<%=getClassCode%>">
				<input type="hidden" name="getCourseYear" id="getCourseYear" value="<%=getCourseYear%>">
				<input type="hidden" name="getCourseCode" id="getCourseCode" value="<%=getCourseCode%>">
				<input type="hidden" name="getLectureCode" id="getLectureCode" value="">
				<input type="hidden" name="getReportMonth" id="getReportMonth" value="<%=getReportMonth%>">
				<input type="hidden" name="getRegFlag" id="getRegFlag" value="">
				<input type="hidden" name="getSendFlag" id="getSendFlag" value="">
				<input type="hidden" name="getOrder" id="getOrder" value="">
				<input type="hidden" name="getSearchType" id="getSearchType" value="MemCode">
				<input type="hidden" name="getSearchWord" id="getSearchWord" value="">
				<input type="file" id="fileInput" name="fileInput" onchange="fileListChangeHandler();" multiple style="display: none;" accept="application/pdf">

				<div style="margin: 15px;">
					<div class="tStyle4">
						<table width="950px" border="0" cellspacing="0" cellpadding="0" style="margin-bottom: 20px;">
							<caption>등록 대상</caption>
							<colgroup>
								<col width="20%">
								<col width="20%">
								<col width="20%">
								<col width="20%">
								<col width="20%">
							</colgroup>
							<thead>
								<tr>
									<th>대상학원</th>
									<th>반분류</th>
									<th>연도</th>
									<th>과정</th>
									<th>리포트</th>
								</tr>
							</thead>
							<tbody>
								<tr>
									<td><%=multipleUpload_AcademyName%></td>
									<td><%=multipleUpload_ClassType%></td>
									<td><%=getCourseYear%></td>
									<td><%=multipleUpload_CourseName%></td>
									<td><%=multipleUpload_ReportMonth%></td>
								</tr>
							</tbody>
						</table>
					</div>
					
					<div class="tStyle4" style="width: 950px; position: relative; ">
						<table width="950px" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:0px;">
							<caption>파일 등록</caption>
						</table>
					</div>

					<div style="width: 950px; position: relative; overflow: hidden;">
						<div style="float: left; margin-bottom: 3px;">
							<label for="tempFileList">
								<img src="http://ams.megastudy.net/img/ams/img/btn/pop_file_load.png">
							</label>
						</div>
						<div style="float: right; margin-top: 3px;">
							<span class="point2">
								파일 등록 : <span style="display: none;">전체(<em id="fileCountALL" class="em_point">0</em>개) <i></i></span> 가능(<em id="fileCountOK" class="point_blue em_point">0</em>개) <i></i> 불가능(<em id="fileCountNO" class="point_org em_point">0</em>개)
							</span>
							<span class="point2" style="margin-left: 15px;">
								용량 : <em id="fileSizeArea" class="point_blue em_point">0.00MB</em><em class="point_gray em_point">/<span id="fileSizeMax">0</span>MB</em>
							</span>
						</div>
					</div>

					<div id="allContainer" class="file_drag_load_wrap">
						<div 
							ondragover="dragOverHandler(event)"
							ondragenter="dragEnterHandler(event)"
							ondrop="dropHandler(event)"
							ondragleave="dragLeaveHandler(event)"
							id="fileInfoContainer"
							class="file_drag_load"
						>
							<p id="fileDropPlaceHolder" class="drag_load_info">첨부할 파일을 마우스로 끌어 오세요</p>

							<div id="fileInfoTable" class="tStyle4" style="width: 100%; position: relative; height: 339px; overflow-y: scroll; padding-bottom: 0; display: none;">
								<table border="0" cellspacing="0" cellpadding="0">
									<colgroup>
										<col width="5%">
										<col width="*">
										<col width="15%">
										<col width="10%">
									</colgroup>
									<thead>
										<tr>
											<th><img onclick="emptyFileList()" class="del_file" src="http://ams.megastudy.net/img/ams/img/btn/pop_tb_del_btn.png"></th>
											<th>파일명</th>
											<th>등록 가능 여부</th>
											<th>용량</th>
										</tr>
									</thead>
									<tbody id="fileInfoRow">
									</tbody>
								</table>
							</div>
						</div>
					</div>
					
					<div style="padding-top: 3px;">
						<span style="color: #a3a3a3; font-size: 11px;"><strong style="color: red;">Privacy-i</strong>를 로그인하지 않으시면 파일이 첨부되지 않을 수 있습니다. 계정 관련 문의는 정보보안팀에 문의 부탁드립니다.</span>
					</div>
					
					<div class="btn">
						<table style="width:950px; margin:30px 0;">
							<tbody>
								<tr>
									<td style="text-align:center;">
										<img id="fileSubmitButton" src="http://ams.megastudy.net/img/ams/img/btn/pop_save_off_bt.png" alt="등록하기(off)">
										<img onclick="closePopup()" src="http://ams.megastudy.net/img/ams/img/btn/pop_cancel_bt.png" alt="취소하기">
									</td>
								</tr>
							</tbody>
						</table>
					</div>
				</div>
			</form>
		</div>
	</div>
	
	<script>
		window.onload = function(){
			onLoadPage('<%=multipleUpload_AcademyName%>', '<%=multipleUpload_ClassType%>', '<%=getCourseYear%>' ,'<%=multipleUpload_CourseName%>' ,'<%=multipleUpload_ReportMonth%>');
		}
	</script>
</body>
</html>
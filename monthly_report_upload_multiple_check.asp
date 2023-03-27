<!-- #include virtual = "/common/inc/RSexec.asp"-->
<!-- #include virtual = "/common/inc/VarDef.asp"-->
<!-- #include virtual = "/common/inc/FunDef.asp"-->
<!-- #include virtual = "/campus_life/monthly_report/inc/monthly_report_functions.asp"-->
<%
	' =======================================================================
	' 설명 : 다중 파일 업로드 > 파일 첨부 상태가 정상인 파일의 리포트 업로드 상태
	' 작성일 : 2023-02-23
	' =======================================================================

	'fetch utf-8
	Session.Codepage = "65001"
	Response.Charset = "utf-8"

	'----------------------------------------------
	' DB 연결 및 RS 객체 생성
	'----------------------------------------------
	Call GlobalDBRSConnection(objConn, DBConMegaAMS, objRs)

	'----------------------------------------------
	' 해당 학원 월간 리포트 리스트 가져오기
	'----------------------------------------------
	getAcaCode = fncRequest("getAcaCode")
	getClassCode = fncRequest("getClassCode")
	getCourseYear = fncRequest("getCourseYear")
	getCourseCode = fncRequest("getCourseCode")
	getLectureCode = fncRequest("getLectureCode")
	getReportMonth = fncRequest("getReportMonth")
	getRegFlag = fncRequest("getRegFlag") 'YN 등록여부
	getSendFlag = fncRequest("getSendFlag") 'YN 알림톡 발송 여부
	getOrder = fncRequest("getOrder")
	getSearchType = fncRequest("getSearchType")
	getSearchWord = fncRequest("getSearchWord")
	memCodeArray = Split(Trim(getSearchWord), ",")

	If IsArray(memCodeArray) Then
		index = 0
		Response.Write "{"
		For Each memCode In memCodeArray
			Call GetMonthlyReportList(getAcaCode, getCourseCode, getClassCode, getLectureCode, getCourseYear, getReportMonth, getRegFlag, getSendFlag, memCode, getSearchType, getOrder)

			If Not objRs.EOF Then
				acaCd = objRs("GH_ACA_CD")
				acaName = objRs("AM_ACA_ABBR")
				lecCd = objRs("GH_LEC_CD")
				lecName = objRs("LM_LEC_NM")
				clsCd = objRs("GH_CLS_CD")
				coleCd = objRs("GH_COLE_CD")
				memCd = objRs("GH_MEM_CD")
				memName = objRs("MM_MEM_NM")
				reportCd = objRs("RR_CRR_CD")
				writer = objRs("RR_WRITER")
				regDate = objRs("RR_WRITE_DATE")

				If index > 0 Then
					Response.Write ","
				End If
				
				Response.Write """" & memCd & """:{""memName"": """ & memName & """,""reportCd"":" & IIF(IsNULL(reportCd), -1, reportCd) & ", ""coleCd"": " & coleCd & ", ""lecCd"": " & lecCd & "}"
				index = index + 1
			End If
		Next
		Response.Write "}"
	End If

	'----------------------------------------------
	' DB 연결 및 RS 객체 Release
	'----------------------------------------------
	Call GlobalDBRSClose(objConn, objRs)
%>
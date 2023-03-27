<!-- #include virtual = "/common/inc/RSexec.asp"-->
<!-- #include virtual = "/common/inc/VarDef.asp"-->
<!-- #include virtual = "/common/inc/FunDef.asp"-->
<!-- #include virtual = "/campus_life/monthly_report/inc/monthly_report_functions.asp" -->
<%
	' =======================================================================
	' 설명 : 다중 파일 업로드 처리
	' 작성일 : 2023-02-23
	' =======================================================================

	'fetch utf-8
	Session.Codepage = "65001"
	Response.Charset = "utf-8"

	'PC, MO 캠퍼스에서는 /ams_data/report/로 가상 디렉토리 설정되어있음 / AMS의 /data/report폴더가 파일서버
	Dim MAX_COUNT : MAX_COUNT = 9999
	Dim MAX_SIZE_MB : MAX_SIZE_MB = 100
	Dim MAX_SIZE_BYTE : MAX_SIZE_BYTE = (MAX_SIZE_MB) * 1024 * 1024
	Dim DirectoryPath : DirectoryPath = "/data/report/" '파일이 저장되는 경로
	Dim objUpload : Set objUpload = Server.CreateObject("DEXT.FileUpload")
	Dim FileSystemObj : Set FileSystemObj = Server.CreateObject("Scripting.FileSystemObject")
	Dim fileTotalSize : fileTotalSize = 0
	Dim reportCodeArray

	objUpload.AutoMakeFolder = True
	objUpload.DefaultPath = Server.MapPath(DirectoryPath)

	Function convertByteIntoKB(fileByte, decimalPoint)
		'======================================
		'KB로 변환
		'======================================
		Dim kiloByte : kiloByte = Round((fileByte / 1024), decimalPoint)
		convertByteIntoKB = kiloByte
	End Function

	Function convertByteIntoMB(fileByte, decimalPoint)
		'======================================
		'MB로 변환
		'======================================
		Dim megaByte : megaByte = Round((fileByte / (1024 * 1024)), decimalPoint)
		convertByteIntoMB = megaByte
	End Function

	Function deleteInsertedReportData()
		'======================================
		'입력한 리포트 정보 전부 삭제
		'======================================
		For Each reportCd In reportCodeArray
			If CInt(reportCd) >= 0 And CStr(reportCd) <> "" Then
				Call DeleteRecordReport(reportCd)
			End If
		Next
	End Function

	Function sendResultAndEnd(resultCode, message, fileName)
		'======================================
		'정상 : 완료 정보(json) 전송
		'오류 : 전송된 파일 전부 삭제 & 리포트 데이터 전부 삭제
		'======================================
		If resultCode = 0 Then
			objUpload.DeleteAllSavedFiles() '전송된 파일 전부 삭제
			deleteInsertedReportData() '리포트 데이터 전부 삭제
		End If

		Response.Write "{"
		Response.Write """resultCode"": " & resultCode
		Response.Write ",""message"": """ & message & """"
		Response.Write ",""fileName"": """ & fileName & """"
		Response.Write "}"
		Response.End
	End Function

	Dim getAcaCode : getAcaCode = objUpload("getAcaCode")
	Dim getClassCode : getClassCode = objUpload("getClassCode")
	Dim getCourseYear : getCourseYear = objUpload("getCourseYear")
	Dim getCourseCode : getCourseCode = objUpload("getCourseCode")
	Dim getLectureCode : getLectureCode = objUpload("getLectureCode")
	Dim getReportMonth : getReportMonth = objUpload("getReportMonth")
	Dim getRegFlag : getRegFlag = objUpload("getRegFlag")
	Dim getSendFlag : getSendFlag = objUpload("getSendFlag")
	Dim getOrder : getOrder = objUpload("getOrder")
	Dim getSearchType : getSearchType = objUpload("getSearchType")
	Dim getSearchWord : getSearchWord = objUpload("getSearchWord")
	Dim fileCount : fileCount = objUpload("fileInput").Count
	Dim EXISTS_fileName : EXISTS_fileName = ""
	Dim MyAcaCode : MyAcaCode = fncRequestCookie("aca_cd")
	Dim MyStafCode : MyStafCode = fncRequestCookie("staf_id")

	ReDim reportCodeArray(fileCount) '파일 갯수만큼 배열 크기 설정
	reportCodeArray(0) = -1

	For index = 1 To fileCount
		'======================================
		' 파일 유효성 확인
		'======================================
		fileTotalSize = fileTotalSize + objUpload("fileInput")(index).fileLen
		orgFileName = objUpload("fileInput")(index).FileName
		orgFileExtension = objUpload("fileInput")(index).fileExtension
		orgFileMimeType = objUpload("fileInput")(index).MimeType
		fileNameArray = Split(Replace(orgFileName, "." & orgFileExtension, ""), "_")

		If orgFileExtension <> "pdf" Then
			Call sendResultAndEnd(0, "[오류발생]" & "pdf 파일만 업로드 가능합니다(1)", "")
		End If

		If orgFileMimeType <> "application/pdf" Then
			Call sendResultAndEnd(0, "[오류발생]" & "pdf 파일만 업로드 가능합니다(2)", "")
		End If

		If UBound(fileNameArray) <> 6 Then '파일 이름 쪼갠 것이 7개가 아닌 경우는 이름 규칙 오류
			Call sendResultAndEnd(0, "[오류발생]" & "파일의 이름 규칙이 올바르지 않습니다", "")
		End If
	Next

	If fileCount < 1 Then
		Call sendResultAndEnd(0, "[오류발생]" & "전송된 파일이 없습니다.", "")
	ElseIf fileTotalSize < 1 Then
		Call sendResultAndEnd(0, "[오류발생]" & "전송된 파일의 크기가 0 입니다.", "")
	ElseIf fileCount > MAX_COUNT Then
		Call sendResultAndEnd(0, "[오류발생]" & "한번에 최대 " & MAX_COUNT & "개까지 업로드 가능합니다.", "")
	ElseIf fileTotalSize > MAX_SIZE_BYTE Then
		Call sendResultAndEnd(0, "[오류발생]" & "한번에 최대 " & convertByteIntoMB(MAX_SIZE_BYTE, 2) & "MB까지 업로드 가능합니다.", "")
	End If

	'======================================
	' DB 연결 및 RS 객체 생성
	'======================================
	Call GlobalDBRSConnection(objConn, DBConMegaAMS, objRs)

	For index = 1 To fileCount
		orgFileName = objUpload("fileInput")(index).FileName
		orgFileExtension = objUpload("fileInput")(index).fileExtension
		fileNameArray = Split(Replace(orgFileName, "." & orgFileExtension, ""), "_")

		'======================================
		' 파일 존재 여부 확인
		'======================================
		If FileSystemObj.FileExists(Server.MapPath(DirectoryPath & orgFileName)) Then
			FileSystemObj.DeleteFile(Server.MapPath(DirectoryPath & orgFileName)) '파일이 존재하면 삭제합니다.
		End If

		'======================================
		' 리포트 데이터 삽입
		'======================================
		If IsArray(fileNameArray) Then
			'======================================
			'해당 학생 월간 리포트 리스트 가져오기
			'======================================
			Call GetMonthlyReportList(getAcaCode, getCourseCode, getClassCode, getLectureCode, fileNameArray(4), fileNameArray(5), getRegFlag, getSendFlag, fileNameArray(6), getSearchType, getOrder)

			If Not objRs.EOF Then
				GH_COLE_CD = objRs("GH_COLE_CD")
				GH_LEC_CD = objRs("GH_LEC_CD")
				
				If fileNameArray(5) = "S" Then
					reportTitle = "수시 지원전략리포트"
				ElseIf fileNameArray(5) = "J" Then
					reportTitle = "정시 지원전략리포트"
				Else
					reportTitle = fileNameArray(5) & "월 MEGA SMART REPORT"
				End If

				resultArray = InsertRecordReport(fileNameArray(6), getAcaCode, getClassCode, GH_COLE_CD, GH_LEC_CD, reportTitle, fileNameArray(4), fileNameArray(5), DirectoryPath & orgFileName, orgFileName, 0, "", 0, MyStafCode)

				If resultArray(0) = "INSERT" Then
					objUpload("fileInput")(index).Save() '원래 이름으로 파일 저장
					reportCodeArray(index) = resultArray(1)
				ElseIf resultArray(0) = "EXISTS" Then
					'----------------------------------------------
					' 리포트 파일 정보 가져오기
					'----------------------------------------------
					fileInfoArray = GetFileInformation(resultArray(1))

					If Not IsArray(fileInfoArray) Then
						EXISTS_fileName = EXISTS_fileName & "파일 정보를 찾을 수 없습니다" & "\n"
					Else
						EXISTS_fileName = EXISTS_fileName & fileInfoArray(1, 0) & "\n" '이미 등록된 리포트 정보
					End If
					' Call sendResultAndEnd(0, "[오류발생]" & "이미 등록된 리포트가 있습니다", EXISTS_fileName) '하나만 찾고 바로 끝낼거면 활성화
				Else
					Call sendResultAndEnd(0, "[오류발생]" & "리포트 등록 중 오류가 발생했습니다", "")
				End If
			End If
		Else
			Call sendResultAndEnd(0, "[오류발생]" & "파일의 이름을 처리할 수 없습니다.", "")
		End If
	Next

	If EXISTS_fileName <> "" Then
		Call sendResultAndEnd(0, "[오류발생]" & "이미 등록된 리포트가 있습니다", "") '모두 찾아서 끝낼거면 활성화
	End If

	Call sendResultAndEnd(1, "파일 등록이 완료되었습니다.", "")

	Set FileSystemObj = Nothing
	Set objUpload = Nothing

	'======================================
	' DB 연결 및 RS 객체 Release
	'======================================
	Call GlobalDBRSClose(objConn, objRs)
%>
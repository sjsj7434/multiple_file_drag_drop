/*
	=======================================================================
	설명 : 다중 파일 업로드 팝업
	작성일 : 2023-03-27
	=======================================================================
*/
if(typeof document.querySelector == "undefined" || typeof fetch == "undefined" || typeof DataTransfer == "undefined"){
	/*
		주요 JS 기능을 사용할 수 없는 브라우저는 페이지 종료 처리
		IE에서는 작동하지 않는 JS가 많아 IE에서는 사용 불가능
	*/
	alert("현재 브라우저는 리포트 일괄 업로드 기능을 정상적으로 사용할 수 없습니다\n크롬(Chrome), 엣지(Edge) 브라우저를 이용해주세요.");
	window.close();
}

const g_studentMap = new Map();
const g_fileInfoMap = new Map();
const g_maxSizeMB = 100;
const g_maxSizeByte = (g_maxSizeMB) * 1024 * 1024;
const g_maxCount = 9999;
let g_dragCounter = 0; //drop 영역의 자식 때문에 leave가 바로 작동하지 않게 함

const setStudentMap = async function(studentNumberArray){
	/*
		비동기 함수
		새로운 파일이 첨부될 때 마다 첨부된 정상 파일의 정보만을 전송하여 리포트 업로드 상태 확인
	*/
	try {
		const getAcaCode = document.reportForm.getAcaCode.value;
		const getClassCode = document.reportForm.getClassCode.value;
		const getCourseYear = document.reportForm.getCourseYear.value;
		const getCourseCode = document.reportForm.getCourseCode.value;
		const getLectureCode = document.reportForm.getLectureCode.value;
		const getReportMonth = document.reportForm.getReportMonth.value;
		const getRegFlag = document.reportForm.getRegFlag.value;
		const getSendFlag = document.reportForm.getSendFlag.value;
		const getOrder = document.reportForm.getOrder.value;
		const getSearchType = document.reportForm.getSearchType.value;
		const getSearchWord = studentNumberArray.join(",");

		const sendData = new URLSearchParams({ //URL Query String
			"getAcaCode": getAcaCode,
			"getClassCode": getClassCode,
			"getCourseYear": getCourseYear,
			"getCourseCode": getCourseCode,
			"getLectureCode": getLectureCode,
			"getReportMonth": getReportMonth,
			"getRegFlag": getRegFlag,
			"getSendFlag": getSendFlag,
			"getOrder": getOrder,
			"getSearchType": getSearchType,
			"getSearchWord": getSearchWord
		});

		const fecthResult = await fetch("/campus_life/monthly_report/monthly_report_upload_multiple_check.asp?" + sendData, {method: "GET"});
		const fecthJSON = await fecthResult.json(); //여러개 학반을 수강 중인 학생은 1개로 압축

		for(key in fecthJSON){
			g_studentMap.set(key, fecthJSON[key]);
		}
	}
	catch (error) {
		document.querySelector("#loadingMessage").innerHTML = "정보를 가져오는 도중 오류가 발생하였습니다";
		
		const formDatas = new FormData(document.reportForm);
		let destination = "/campus_life/monthly_report/monthly_report_upload_multiple.asp";
		let index = 0;
		for(key of formDatas.keys()){
			if(key !== "fileInput"){
				destination += `${index === 0 ? "?" : "&"}${key}=${formDatas.get(key)}`;
				index++;
			}
		}
		destination += `&fileCount=0`;

		scriptErrorLogSend("setStudentMap : " + destination, (error.name + " : " + error.message));

		alert("정보를 가져오는 도중 오류가 발생하였습니다");
		window.close();
	}
}

const splitFileName = function(fileName){
	/*
		파일의 이름을 [_]로 구분하여 반환
	*/
	const returnResult = {};
	const fileNameSplit = fileName.split(".");
	const fileExtension = fileNameSplit.length < 2 ? fileNameSplit[1] : fileNameSplit[fileNameSplit.length - 1];
	const fileNameArray = fileName.replace("." + fileExtension, "").split("_");
	let status = false;
	let studentName = "";
	let studentNumber = "";
	let reportYear = "";
	let reportMonth = "";
	let fileCodeName = "";

	if(fileNameArray.length == 7){
		if(isNaN(fileNameArray[4]) || isNaN(fileNameArray[6])){
			fileCodeName = fileName;
		}
		else{
			status = true;
			studentName = fileNameArray[0];
			studentNumber = fileNameArray[6];
			reportYear = fileNameArray[4];
			reportMonth = fileNameArray[5];
			fileCodeName = `${reportYear}_${reportMonth}_${studentNumber}.${fileExtension}`;
		}
	}
	else{
		fileCodeName = fileName;
	}

	returnResult.status = status;
	returnResult.fileExtension = fileExtension;
	returnResult.fileCodeName = fileCodeName;
	returnResult.studentName = studentName;
	returnResult.reportYear = reportYear;
	returnResult.reportMonth = reportMonth;
	returnResult.studentNumber = studentNumber;

	return returnResult;
}

const convertByteIntoKB = function(fileByte, decimalPoint){
	/*
		byte => KB 변환
	*/
	const kiloByte = (fileByte / 1024).toFixed(decimalPoint);

	return kiloByte;
}

const convertByteIntoMB = function(fileByte, decimalPoint){
	/*
		byte => MB 변환
	*/
	const megaByte = (fileByte / (1024 * 1024)).toFixed(decimalPoint);

	return megaByte;
}

const convertByteIntoGB = function(fileByte, decimalPoint){
	/*
		byte => GB 변환
	*/
	const gigaByte = (fileByte / (1024 * 1024 * 1024)).toFixed(decimalPoint);

	return gigaByte;
}

const getFileListSize = function(fileList){
	/*
		업로드 가능한 파일 목록 크기 확인
	*/
	let fileTotalSize = 0;

	[...fileList].forEach((file, index) => {
		fileTotalSize += file.size;
	});

	return fileTotalSize;
}

const isThereDuplicateFile = function(orgFileMap, newFileList) {
	/*
		동일한 파일이 존재하는지 확인, 파일 이름 끝 부분의 [년도_월_학번]이 같다면 중복이다
		파일 이름 내 학생 이름은 비교 대상에서 제외(한글 비교는 불안정하여 제외 - 학원개발팀장)
		전체 파일 이름으로 비교해버리면 [홍길동_2022_3_12345.pdf] & [박지성_2022_3_12345.pdf]는 다른 파일이 되어 서버로 전송되어버림

		newFileList안에서 중복 확인 1번
		orgFileMap & newFileList안에서 중복 확인 1번

		true : 중복이 존재
		false : 중복 없음
	*/
	const newFileNameArray = [];
	let checkResult = false;
	let message = "";

	for(const newFile of [...newFileList]){
		const fileInfo = splitFileName(newFile.name);

		if (newFileNameArray.includes(fileInfo.fileCodeName) === true) { //올리려는 파일 목록 중에 겹치는 경우(리포트의 학생 이름은 다르지만 [년도_월_학번]이 같은 경우)
			checkResult = true;
			message = `추가하려는 파일 중에 [${fileInfo.fileCodeName}]과 동일한 학번을 가진 파일이 존재합니다`;

			return {"result": checkResult, "message": message};
		}
		else if(orgFileMap.has(fileInfo.fileCodeName) === true){ //이미 목록에 추가된 파일 중에 파일의 이름이 겹치는 경우
			checkResult = true;
			message = "동일한 파일이 이미 첨부되어 있습니다";

			return {"result": checkResult, "message": message};
		}
		else{ //중복 검사 통과
			newFileNameArray.push(fileInfo.fileCodeName);
		}
	}

	return {"result": checkResult, "message": message};
}

const isValidFile = function(file, fileInfo){
	/*
		파일이 업로드 가능한지 확인
	*/
	const getCourseYear = document.reportForm.getCourseYear.value;
	const getReportMonth = document.reportForm.getReportMonth.value;
	let result = false;
	let fileStatusTag = "";
	let invalidReason = "";

	if(file.type != "application/pdf"){
		fileStatusTag = "불가능";
		invalidReason = "pdf 파일이 아닙니다";
	}
	else if(file.size < 1){
		fileStatusTag = "불가능";
		invalidReason = "파일의 크기가 0입니다";
	}
	else if(file.size > g_maxSizeByte){
		fileStatusTag = "불가능";
		invalidReason = "파일의 크기가 너무 큽니다";
	}
	else{
		if(fileInfo.status === true){
			if(fileInfo.reportYear !== getCourseYear){
				fileStatusTag = "불가능";
				invalidReason = `파일명 내 연도가 ${getCourseYear}(이)가 아닙니다`;
			}
			else if(fileInfo.reportMonth !== getReportMonth){
				fileStatusTag = "불가능";
				invalidReason = `파일명 내 월이 ${getReportMonth}(이)가 아닙니다`;
			}
			else if(g_studentMap.get(fileInfo.studentNumber) === undefined){
				fileStatusTag = "불가능";
				invalidReason = `파일명 내 학번 ${fileInfo.studentNumber}이 존재하지 않습니다`;
			}
			else if(g_studentMap.get(fileInfo.studentNumber).reportCd >= 0){
				fileStatusTag = "불가능";
				invalidReason = `이미 등록된 파일이 있습니다`;
			}
			else{
				result = true;
				fileStatusTag = "가능";
				invalidReason = "";
			}
		}
		else{
			fileStatusTag = "불가능";
			invalidReason = "파일명이 올바르지 않습니다";
		}
	}

	return {"result": result, "fileStatusTag": fileStatusTag, "invalidReason": invalidReason};
}

const mergeFileList = async function(fileListArray){
	/*
		파일 목록 객체 합치기
	*/
	const mergedFileList = new DataTransfer(); //새롭게 fileList를 만듦

	const studentNumberArray = [];
	for(const fileList of fileListArray){
		for (const file of fileList) {
			const fileInfo = splitFileName(file.name);
			if(fileInfo.studentNumber !== ""){
				studentNumberArray.push(fileInfo.studentNumber);
			}
		}
	}

	openModal("리포트 정보를 구성 중입니다", "");
	g_studentMap.clear();
	await setStudentMap(studentNumberArray);
	
	for(const fileList of fileListArray){
		for (const file of fileList) {
			const fileInfo = splitFileName(file.name);
			const validInfo = isValidFile(file, fileInfo);
			
			//가능, 불가능 목록을 위해 전부 추가
			g_fileInfoMap.set(fileInfo.fileCodeName, {
				"fileOrgName": file.name
				, "size": file.size
				, "isValid": validInfo.result
				, "fileStatusTag": validInfo.fileStatusTag
				, "invalidReason": validInfo.invalidReason
			});

			if(validInfo.result === true){
				mergedFileList.items.add(file); //새로운 fileList에 파일 추가
			}
		}
	}
	closeModal();

	return mergedFileList;
}

const copyIntoRealInput = function(){
	/*
		파일 가져오기를 눌러서 파일을 업로드하는 경우
	*/
	const fileInput = document.querySelector("#fileInput"); //기존 fileList
	const tempFileList = document.querySelector("#tempFileList"); //임시 fileList, 기존 file input은 dropzone이므로 임시가 필요했음
	const checkResult = isThereDuplicateFile(g_fileInfoMap, tempFileList.files);

	if(checkResult.result === false){ //중복 없음
		mergeFileList([fileInput.files, tempFileList.files]).then((mergedFileList) => {
			fileInput.files = mergedFileList.files; //새롭게 만든 fileList를 기존에 덮어씀
			tempFileList.value = ""; //임시 fileList reset

			fileListChangeHandler(); //변경사항을 기존 input file에 적용
		});
	}
	else{ //중복이 존재
		alert(checkResult.message);
	}
}

const fileListChangeHandler = function(){
	const fileInput = document.querySelector("#fileInput");
	
	setFileList(g_fileInfoMap);
}

const dropHandler = function(event) {
	/*
		파일을 끌어다가 놓는 경우(drag & drop)
	*/
	event.preventDefault(); //브라우저의 기본 drag 동작을 무시하도록
	
	if(event.dataTransfer.files.length === 0){
		dragLeaveHandler(event);
		return;
	}

	const fileInput = document.querySelector("#fileInput"); //기존 fileList
	const checkResult = isThereDuplicateFile(g_fileInfoMap, event.dataTransfer.files);
	
	if(checkResult.result === false){ //중복 없음
		mergeFileList([fileInput.files, event.dataTransfer.files]).then((mergedFileList) => {
			fileInput.files = mergedFileList.files; //새롭게 만든 fileList를 기존에 덮어씀

			setFileList(g_fileInfoMap); //파일 목록 및 정보 갱신
		});
	}
	else{ //중복이 존재
		alert(checkResult.message);
	}

	dragLeaveHandler(event); //드래그 종료
}

const dragOverHandler = function(event){
	/*
		드래그 상태로 영역 위에 올라와 있을 때
	*/
	event.preventDefault(); //브라우저의 기본 drag 동작을 무시하도록
}

const dragEnterHandler = function(event){
	/*
		드래그 상태로 영역에 들어올 때
	*/
	event.preventDefault(); //브라우저의 기본 drag 동작을 무시하도록
	g_dragCounter++;

	const fileInfoContainer = document.querySelector("#fileInfoContainer");
	const fileInfoTable = document.querySelector("#fileInfoTable");

	fileInfoContainer.classList.add("drag_on");
	fileInfoTable.classList.add("noEvents");
}

const dragLeaveHandler = function(event){
	/*
		드래그 상태가 끝날 때(영역 떠남, 드래그 끝남)
	*/
	event.preventDefault(); //브라우저의 기본 drag 동작을 무시하도록
	g_dragCounter--;

	const fileInfoContainer = document.querySelector("#fileInfoContainer");
	const fileInfoTable = document.querySelector("#fileInfoTable");

	if(g_dragCounter == 0){
		fileInfoContainer.classList.remove("drag_on");
		fileInfoTable.classList.remove("noEvents");
	}
}

const setFileList = function(fileMap){
	/*
		파일 첨부 목록 그리기
	*/
	const fileInfoRow = document.querySelector("#fileInfoRow");
	let mapKeys = fileMap.keys();
	let fileCountOK = 0;
	let fileCountNO = 0;
	let fileTotalSize = 0;

	fileInfoRow.innerHTML = "";
	for(fileCodeName of mapKeys){
		if(fileMap.get(fileCodeName).isValid === true){
			fileCountOK++;
			fileTotalSize += fileMap.get(fileCodeName).size;
		}
		else{
			fileCountNO++;
		}

		fileInfoRow.innerHTML += `
			<tr class="${fileMap.get(fileCodeName).isValid === true ? "" : "caution_line"}">
				<td>
					<img onclick="deleteFromUploadList('${fileMap.get(fileCodeName).fileOrgName}', '${fileCodeName}')" class="del_file" src="http://ams.megastudy.net/img/ams/img/btn/pop_tb_del_btn.png">
				</td>
				<td align="left" style="padding: 3px;">
					<div style="width: 630px; overflow: hidden; white-space: nowrap; text-overflow: ellipsis">
						${fileMap.get(fileCodeName).fileOrgName}
					</div>
				</td>
				<td align="center" style="padding: 3px;">
					${fileMap.get(fileCodeName).isValid === true ? "가능" : "<span style='cursor: help;' title='" + fileMap.get(fileCodeName).invalidReason + "'>" + fileMap.get(fileCodeName).fileStatusTag + " <img src='http://ams.megastudy.net/img/ams/img/btn/pop_caution_ico.png'></span>"}
				</td>
				<td align="center" style="padding: 3px;">
					${convertByteIntoMB(fileMap.get(fileCodeName).size, 2)} MB
				</td>
			</tr>
		`;
	}

	if(fileInfoRow.innerHTML === ""){
		document.querySelector("#allContainer").classList.remove("att_file");
		document.querySelector("#fileInfoTable").style.display = "none";
		document.querySelector("#fileSubmitButton").src = "http://ams.megastudy.net/img/ams/img/btn/pop_save_off_bt.png";
		document.querySelector("#fileSubmitButton").onclick = () => {};
	}
	else{
		document.querySelector("#allContainer").classList.add("att_file");
		document.querySelector("#fileInfoTable").style.display = "block";
		document.querySelector("#fileSubmitButton").src = "http://ams.megastudy.net/img/ams/img/btn/pop_save_on_bt.png";
		document.querySelector("#fileSubmitButton").onclick = () => {sendFiles()};
	}

	if(fileTotalSize > g_maxSizeByte){
		document.querySelector("#fileSizeArea").classList.add("point_org");
		document.querySelector("#fileSizeArea").classList.remove("point_blue");
	}
	else{
		document.querySelector("#fileSizeArea").classList.add("point_blue");
		document.querySelector("#fileSizeArea").classList.remove("point_org");
	}
	
	document.querySelector("#fileCountALL").innerHTML = fileMap.size;
	document.querySelector("#fileCountOK").innerHTML = fileCountOK;
	document.querySelector("#fileCountNO").innerHTML = fileCountNO;
	document.querySelector("#fileSizeArea").innerHTML = `${convertByteIntoMB(fileTotalSize, 2)}MB`;
}

const sendFiles = async function(){
	/*
		파일 업로드
	*/
	const fileInput = document.querySelector("#fileInput");

	if(checkUploadLimit_fileList(fileInput.files) === true){
		if(confirm("파일을 전송하시겠습니까?") === true){
			window.onbeforeunload = (event) => {
				event.preventDefault();
				
				const formDatas = new FormData(document.reportForm);
				let destination = "/campus_life/monthly_report/monthly_report_upload_multiple_save.asp";
				let index = 0;
				for(key of formDatas.keys()){
					if(key !== "fileInput"){
						destination += `${index === 0 ? "?" : "&"}${key}=${formDatas.get(key)}`;
						index++;
					}
				}
				destination += `&fileCount=${document.reportForm.fileInput.files.length}`;

				scriptErrorLogSend("sendFiles : " + destination, "exit : window was closed or tried to close before file upload finished");

				return "";
			}

			openModal("리포트 파일을 업로드 중입니다", `${document.querySelector("#fileCountOK").innerHTML}개(${document.querySelector("#fileSizeArea").innerHTML})`);
			
			const sendData = new FormData(document.reportForm);
			
			const fecthResult = await fetch("/campus_life/monthly_report/monthly_report_upload_multiple_save.asp", {
				method: "POST",
				cache: "no-cache",
				headers: {}, //multipart 헤더를 넣어주면 브라우저에서 올바른 boundary를 설정해줄 수 없으므로 빈 헤더로 보냄
				body: sendData
			});

			const fecthJSON = await fecthResult.json();

			window.onbeforeunload = (event) => {} //닫기 전 확인 창 제거

			if(fecthJSON.resultCode === 1){
				//업로드 성공
				alert(`${fecthJSON.message}\n[총 ${document.querySelector("#fileCountALL").innerHTML}개 중 ${document.querySelector("#fileCountOK").innerHTML}개 완료]`);

				window.opener.goSearch();
				location.reload();
			}
			else if(fecthJSON.resultCode === 0){
				//업로드 오류
				alert(fecthJSON.message + "\n" + fecthJSON.fileName);
				location.reload();
			}
		}
	}
}

const checkUploadLimit_fileList = function(fileList){
	/*
		업로드할 파일 목록 검사
	*/
	const fileCount = fileList.length;
	const fileTotalSize = getFileListSize(fileList);

	if(fileCount < 1){
		alert("업로드할 파일이 없습니다.");
		return false;
	}
	else if(fileTotalSize < 1){
		alert("업로드할 파일의 크기가 0 Byte 입니다.");
		return false;
	}
	else if(fileCount > g_maxCount){
		alert(`업로드할 파일의 개수가 너무 많습니다.\n최대 업로드 개수는 ${g_maxCount}개 입니다.`);
		return false;
	}
	else if(fileTotalSize > g_maxSizeByte){
		alert("최대 등록 용량을 초과했습니다.");
		return false;
	}
	return true;
}

const deleteFromUploadList = function(fileName, fileCodeName) {
	/*
		파일 목록 중에 특정 1개만 지우기
	*/
	const fileInput = document.querySelector("#fileInput");
	const newFileList = new DataTransfer();

	if(confirm("파일을 삭제하시겠습니까?") === false){
		return;
	}

	for(file of fileInput.files) {
		if(fileName !== file.name){
			newFileList.items.add(file);
		}
	}

	fileInput.files = newFileList.files;
	g_fileInfoMap.delete(fileCodeName); //codename이 들어가야 함
	
	setFileList(g_fileInfoMap);
}

const emptyFileList = function(){
	/*
		파일 목록 전부 지우기
	*/
	const fileInput = document.querySelector("#fileInput");

	if(confirm("전체 파일을 삭제하시겠습니까?") === false){
		return;
	}

	fileInput.value = "";
	g_fileInfoMap.clear();

	setFileList(g_fileInfoMap);
}

const modalPrevent = function(event){
	/*
		dialog esc눌러서 닫기 불가능하게 처리
	*/
	event.preventDefault(); //esc눌러서 닫기 불가능하게
	document.querySelector("#warningMessage").innerHTML = "ESC키를 누르지 마시고 조금만 기다려주세요";
}

const openModal = function(loadingMessage, subMessage){
	/*
		dialog 열기
	*/
	document.querySelector("body").style.position = "fixed";
	document.querySelector("#loadingModal").showModal();
	document.querySelector("#loadingModal").addEventListener("cancel", modalPrevent);
	document.querySelector("#loadingMessage").innerHTML = loadingMessage;
	document.querySelector("#subMessage").innerHTML = subMessage;
}
const closeModal = function(){
	/*
		dialog 닫기
	*/
	document.querySelector("body").style.position = "";
	document.querySelector("#loadingModal").close();
	document.querySelector("#loadingModal").removeEventListener("cancel", modalPrevent);
	document.querySelector("#warningMessage").innerHTML = "&nbsp;";
	document.querySelector("#loadingMessage").innerHTML = "&nbsp;";
	document.querySelector("#subMessage").innerHTML = "&nbsp;";
}

const closePopup = function(){
	/*
		파일 등록 팝업 닫기
	*/
	if(confirm("파일 등록을 취소하시겠습니까?") === true){
		window.onbeforeunload = (event) => {}
		window.close();
	}
}

const onLoadPage = function(AcademyName, ClassType, CourseYear, CourseName, ReportMonth){
	/*
		파일 등록 팝업 열리면 초기화
	*/
	if(AcademyName === "" || ClassType === "" || CourseYear === "" || CourseName === "" || ReportMonth === ""){
		window.document.body.innerHTML = "";
		alert("검색 조건을 다시 확인해주세요");
		window.close();
		return;
	}

	document.querySelector("#fileSizeMax").innerHTML = g_maxSizeMB;
}
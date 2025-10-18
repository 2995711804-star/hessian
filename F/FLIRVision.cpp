#include "FLIRVision.h"

#include <string>
#ifdef _WIN32
#include <windows.h>
#endif

// �� UTF-8 std::string ·��תΪ���ִ������� CreateDirectoryW��
// ���� TRUE ��ʾ�����ɹ������Ŀ¼�Ѵ���Ҳ��Ϊ�ɹ���
static inline BOOL CreateDirectoryU8(const std::string& utf8_path) {
#ifdef _WIN32
	// 1) ������Ҫ�Ŀ��ַ�������������ֹ����
	int n = MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, nullptr, 0);
	if (n <= 0) return FALSE;

	// 2) ���䲢ת��
	std::wstring wpath;
	wpath.resize(static_cast<size_t>(n - 1));        // ��������ֹ��
	if (n > 1) {
		MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, &wpath[0], n);
	}

	// 3) ���ÿ��ַ��� CreateDirectory
	BOOL ok = ::CreateDirectoryW(wpath.c_str(), nullptr);
	if (!ok) {
		DWORD err = GetLastError();
		if (err == ERROR_ALREADY_EXISTS) return TRUE; // �Ѵ���Ҳ��ɹ�
	}
	return ok;
#else
	// �� Windows ƽ̨��ռλ������ʵ�֣�
	return TRUE;
#endif
}


FLIRVision::FLIRVision(QWidget *parent)
    : QMainWindow(parent)
{
    ui.setupUi(this);

	connect(ui.spinBox_exposure, SIGNAL(valueChanged(int)), ui.horizontalSlider_exposure, SLOT(setValue(int)));
	connect(ui.horizontalSlider_exposure, SIGNAL(valueChanged(int)), ui.spinBox_exposure, SLOT(setValue(int)));

	connect(ui.spinBox_gain, SIGNAL(valueChanged(int)), ui.horizontalSlider_gain, SLOT(setValue(int)));
	connect(ui.horizontalSlider_gain, SIGNAL(valueChanged(int)), ui.spinBox_gain, SLOT(setValue(int)));

	connect(ui.spinBox_gamma, static_cast<void(QDoubleSpinBox::*)(double)>(&QDoubleSpinBox::valueChanged), ui.horizontalSlider_gamma, [=](double v)
	{
		//�Ŵ�10����QSlider����ʾ
		ui.horizontalSlider_gamma->setValue(v * 100);
	});
	connect(ui.horizontalSlider_gamma, &QSlider::valueChanged, ui.spinBox_gamma, [=](int v)
	{
		//��С10����QDoubleSpinBox����ʾ
		ui.spinBox_gamma->setValue((double)v / 100);
	});

	connect(ui.Information, SIGNAL(textChanged()), SLOT(slotTextTcpChanged()));
}

FLIRVision::~FLIRVision()
{}

//��ʼ�����
void FLIRVision::on_Initialize_clicked()
{
	//�½����ϵͳ�����ڳ�ʼ���͹������
	system = System::GetInstance();
	//��ȡ����б�����⵽�������Ӽ���������
	camList = system->GetCameras();
	//��ȡ�����Ŀ���������ʾ
	int numCameras = camList.GetSize();
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("��ϵͳ��ʼ������⵽�������Ϊ��") + QString::number(numCameras) + "\n");
	ui.Information->moveCursor(QTextCursor::End);

	if (numCameras == 0)
	{
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("��δ��⵽���") + "\n");
		ui.Information->moveCursor(QTextCursor::End);
		camList.Clear();
		//�ͷ�ϵͳ
		system->ReleaseInstance();
	}
	//���ʵ����������ֻ��һ�������ѡ���һ�������������indexΪ0
	pCam = camList.GetByIndex(0);
	//start��ťͣ��
	ui.Initialize->setDisabled(true);
	//stop��ť����
	ui.Pause->setDisabled(false);
	//�ر���Ƶ����ť����
	ui.videostreaming->setDisabled(true);	
	//�����ؼ��ڹر���Ƶ��������Ų���ʹ��
    ui.Trigger->setDisabled(true);
	ui.singleTrigger->setDisabled(true);	
	//q��������ѭ����ʾ��������ͣ��Ƶ��
	q = 0;
	//�ж�ͼ���Ƿ�����
	on_Piccount_valueChanged();
	//��ʼ���������
	Configure(pCam);
	//������ʾ��Ƶ��
	ImshowCamera();
}

//��ʼ���������
void FLIRVision::Configure(CameraPtr pCam)
{
	//��ȡ������豸ӳ���
	INodeMap& nodeMapTLDevice = pCam->GetTLDeviceNodeMap();
	//��ʼ�����
	pCam->Init();
	//��ȡ����Ľڵ�ӳ��
	INodeMap& nodeMap = pCam->GetNodeMap();
	try
	{
		//������Ľڵ�ӳ���л�ȡ����Ϊ "AcquisitionMode" �Ľڵ㲢���丳ֵ����Ϊ ptrAcquisitionMode ��ö��ָ��
		CEnumerationPtr ptrAcquisitionMode = nodeMap.GetNode("AcquisitionMode");
		//��"AcquisitionMode"�ڵ��ö��ֵ�л�ȡ����Ϊ"Continuous"��ö����Ŀ����ֵ��"ptrAcquisitionModeContinuous"ö����Ŀָ��
		CEnumEntryPtr ptrAcquisitionModeContinuous = ptrAcquisitionMode->GetEntryByName("Continuous");
		//��ȡ"Continuous"��ֵ������ֵ��acquisitionModeContinuous
		const int64_t acquisitionModeContinuous = ptrAcquisitionModeContinuous->GetValue();
		//������Ĳɼ�ģʽ����Ϊ����ģʽ
		ptrAcquisitionMode->SetIntValue(acquisitionModeContinuous);

		//�ر��Զ��ع⣬��ʼ�ع�ֵ����δ50000
		CEnumerationPtr ptrExposureAuto = nodeMap.GetNode("ExposureAuto");
		CEnumEntryPtr ptrExposureAutoOff = ptrExposureAuto->GetEntryByName("Off");
		ptrExposureAuto->SetIntValue(ptrExposureAutoOff->GetValue());
		CFloatPtr ptrExposureTime = nodeMap.GetNode("ExposureTime");
		const double exposureTimeMax = ptrExposureTime->GetMax(); 
		double exposureTimeToSet = 50000.0;
		if (exposureTimeToSet > exposureTimeMax)
		{ 
			exposureTimeToSet = exposureTimeMax; 
		}
		ptrExposureTime->SetValue(exposureTimeToSet);
		ui.spinBox_exposure->setValue(int(exposureTimeToSet));
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("���Զ��ع�ر�") + "\n"); 
		ui.Information->moveCursor(QTextCursor::End);

		//��ʼ���رմ�������
		CEnumerationPtr ptrTriggerMode = nodeMap.GetNode("TriggerMode");
		CEnumEntryPtr ptrTriggerModeOff = ptrTriggerMode->GetEntryByName("Off");
		ptrTriggerMode->SetIntValue(ptrTriggerModeOff->GetValue());
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("���������ܹر�") + "\n");
		ui.Information->moveCursor(QTextCursor::End);

		//�ر��Զ����棬��ʼ����1
		CEnumerationPtr gainAuto = nodeMap.GetNode("GainAuto");
		gainAuto->SetIntValue(gainAuto->GetEntryByName("Off")->GetValue());
		CFloatPtr gainValue = nodeMap.GetNode("Gain");
		gainValue->SetValue(10.5);
		ui.spinBox_gain->setValue(1);
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("���Զ�����ر�") + "\n");
		ui.Information->moveCursor(QTextCursor::End);

		//��ʼGamma1
		CFloatPtr gamma = nodeMap.GetNode("Gamma");
		gamma->SetValue(1);
		ui.spinBox_gamma->setValue(1);
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("����ǰGammaֵΪ1") + "\n");
		ui.Information->moveCursor(QTextCursor::End);

	}
	catch (Spinnaker::Exception& e)
	{
		cout << "Error: " << e.what() << endl;
	}
}

//ʵʱ��ʾ��Ƶ��
void FLIRVision::ImshowCamera()
{
	//��ʼ�����ͼ��ɼ����̣��Ӵ˿�ʼ����������ȡͼ��
	pCam->BeginAcquisition();

	while (true)
	{
		//����ͼ��ָ�벢��ȡ��һ֡ͼ��
		ImagePtr pResultImage = pCam->GetNextImage();
		//ͼ����
		const size_t width = pResultImage->GetWidth();
		//ͼ��߶�
		const size_t height = pResultImage->GetHeight();
		//ͼ���ʽת��
		ImagePtr rgbImage = pResultImage->Convert(PixelFormat_BGR8);
		void* image_data = rgbImage->GetData();
		unsigned int stride = rgbImage->GetStride();
		Mat current_frame = cv::Mat(height, width, CV_8UC3, image_data, stride);
		//Mat display_frame = cv::Mat();
		//cv::resize(current_frame, display_frame, Size(width, height));
		QImage img(current_frame.data, current_frame.cols, current_frame.rows, QImage::Format_RGB888);
		ui.camera->setPixmap(QPixmap::fromImage(img));
		cv::waitKey(1);
		//�ͷ�ͼ��ָ��
		pResultImage->Release();
		if (q == 1)
		{
			break;
		}
	}
	pCam->EndAcquisition();// ���������ͼ��ɼ�
}

//����Ƶ��
void FLIRVision::on_videostreaming_clicked()
{
	q = 0;
	ui.Pause->setDisabled(false);
	ui.videostreaming->setDisabled(true);
	ui.Trigger->setDisabled(true);
	ui.singleTrigger->setDisabled(true);
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("������Ƶ��") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	ImshowCamera();
}

//��ͣ��ȡͼ����
void FLIRVision::on_Pause_clicked()//�ر����
{
	q = 1;
	ui.Initialize->setDisabled(false);
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("�ر���Ƶ��") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	ui.Pause->setDisabled(true);
	ui.videostreaming->setDisabled(false);
	////�����ؼ��ڹر���Ƶ��������Ų���ʹ��
	ui.Trigger->setDisabled(false);
	ui.singleTrigger->setDisabled(false);
}

//�ֶ������ع�
void FLIRVision::on_spinBox_exposure_valueChanged()
{
	double exposetimeval = ui.spinBox_exposure->value();
	INodeMap& nodeMap = pCam->GetNodeMap();

	CEnumerationPtr ptrExposureAuto = nodeMap.GetNode("ExposureAuto");
	CEnumEntryPtr ptrExposureAutoOff = ptrExposureAuto->GetEntryByName("Off");
	ptrExposureAuto->SetIntValue(ptrExposureAutoOff->GetValue());

	CFloatPtr ptrExposureTime = nodeMap.GetNode("ExposureTime");
	ptrExposureTime->SetValue(int(exposetimeval));
}

//�ֶ���������
void FLIRVision::on_spinBox_gain_valueChanged()
{
	double gainval = ui.spinBox_gain->value();
	INodeMap& nodeMap = pCam->GetNodeMap();

	CEnumerationPtr gainAuto = nodeMap.GetNode("GainAuto");
	gainAuto->SetIntValue(gainAuto->GetEntryByName("Off")->GetValue());

	CFloatPtr gainValue = nodeMap.GetNode("Gain");
	gainValue->SetValue(gainval);
}

//�ֶ�����Gamma
void FLIRVision::on_spinBox_gamma_valueChanged()
{
	double gammaval = ui.spinBox_gamma->value();
	INodeMap& nodeMap = pCam->GetNodeMap();

	CFloatPtr gamma = nodeMap.GetNode("Gamma");
	gamma->SetValue(gammaval);
}

//��׽ͼ��
void FLIRVision::on_Catchimages_clicked()
{
	//����ͼ��ָ�벢��ȡ��һ֡ͼ��
	ImagePtr CatchImage = pCam->GetNextImage();
	//ͼ����
	const size_t width = CatchImage->GetWidth();
	//ͼ��߶�
	const size_t height = CatchImage->GetHeight();
	//ͼ���ʽת��
	ImagePtr rgbImage = CatchImage->Convert(PixelFormat_Mono8);
	unsigned int rowBytes = (double)rgbImage->GetImageSize() / (double)height;
	//��ͼ��ת��ΪMat��ʽ+
	frame = Mat(height, width, CV_8UC1, rgbImage->GetData(), rowBytes);
	//��ȡ����ֵ
	int group = ui.Groupcount->value();
	//��ȡͼ����ֵ
	int i = ui.Piccount->value();
	//������
	string file_Name = ".\\image\\" + to_string(group);
	//std::wstring file_Name = L".\\image\\" + std::to_wstring(group);


	//ͼƬ����λ��
	string img_Name = ".\\image\\" + to_string(group) + "\\" + to_string(i) + ".bmp";
	//�����ļ���
	BOOL flag = CreateDirectoryU8(file_Name);
	imwrite(img_Name, frame);
	i++;
	ui.Piccount->setValue(i);
	CatchImage->Release();//�ͷ�ͼ��ָ��
}

//�ж�ͼ���Ƿ�����
bool isFileExists_ifstream(string& name)
{
	ifstream f(name.c_str());
	return f.good();
}

void FLIRVision::on_Piccount_valueChanged()
{
	int group = ui.Groupcount->value();
	int i = ui.Piccount->value();
	string img_Name = ".\\image\\" + to_string(group) + "\\" + to_string(i) + ".bmp";
	bool flag = isFileExists_ifstream(img_Name);
	if (flag == 0)
	{
		ui.capturestate->setText(QString::fromLocal8Bit("δ����"));
		ui.capturestate->setStyleSheet("color:red");
	}
	else if (flag == 1)
	{
		ui.capturestate->setText(QString::fromLocal8Bit("������"));
		ui.capturestate->setStyleSheet("color:green");
	}
}

//�ı�����ͼ��תΪ�����һ��
void FLIRVision::on_Groupcount_valueChanged()
{
	on_Piccount_valueChanged();
	ui.Piccount->setValue(1);
}

//�˳�����
void FLIRVision::on_Exit_clicked()
{
	//�رյ�ǰ����
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("ϵͳ�ر�") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	this->close();
}

//�鿴ͼƬ
void FLIRVision::on_Image_clicked()//�鿴�ɼ�ͼƬ
{
	QDesktopServices::openUrl(QUrl::fromLocalFile(".\\image\\"));
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("�򿪲ɼ��ļ���") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
}

//--------����--------//
void FLIRVision::on_Trigger_clicked()
{
	//��ȡ����Ľڵ�ӳ��
	INodeMap& nodeMap = pCam->GetNodeMap();
	on_ConfigureTrigger(nodeMap);
	AcquireImages(pCam, nodeMap);
	ResetTrigger(nodeMap);
}

void FLIRVision::on_singleTrigger_clicked()
{
	//��ȡ����Ľڵ�ӳ��
	INodeMap& nodeMap = pCam->GetNodeMap();
	on_ConfigureTrigger(nodeMap);
	AcquireImagessingle(pCam, nodeMap);
	ResetTrigger(nodeMap);
}

//�鿴����ͼƬ
void FLIRVision::on_Triggerimage_clicked()//�鿴�ɼ�ͼƬ
{
	QDesktopServices::openUrl(QUrl::fromLocalFile(".\\triggerimage\\"));
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("�򿪴����ļ���") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
}

void FLIRVision::on_ConfigureTrigger(INodeMap& nodeMap)
{
	try
	{
		//�رմ���ģʽ�����ô���ʱ����ѡ����ִ�����Ҫ������ģʽ�ر�
		CEnumerationPtr ptrTriggerMode = nodeMap.GetNode("TriggerMode");
		CEnumEntryPtr ptrTriggerModeOff = ptrTriggerMode->GetEntryByName("Off");
		ptrTriggerMode->SetIntValue(ptrTriggerModeOff->GetValue());

		CEnumerationPtr ptrTriggerSelector = nodeMap.GetNode("TriggerSelector");
		CEnumEntryPtr ptrTriggerSelectorFrameStart = ptrTriggerSelector->GetEntryByName("FrameStart");
		ptrTriggerSelector->SetIntValue(ptrTriggerSelectorFrameStart->GetValue());

		//ѡ�񴥷�ԴӲ����Software������Line0��Line2��Line3
		CEnumerationPtr ptrTriggerSource = nodeMap.GetNode("TriggerSource");
	    CEnumEntryPtr ptrTriggerSourceHardware = ptrTriggerSource->GetEntryByName("Line3");
	    ptrTriggerSource->SetIntValue(ptrTriggerSourceHardware->GetValue());
	    cout << "����Դѡ��Line3" << endl;

		CEnumEntryPtr ptrTriggerModeOn = ptrTriggerMode->GetEntryByName("On");
		ptrTriggerMode->SetIntValue(ptrTriggerModeOn->GetValue());
		pCam->BeginAcquisition();
		ui.Information->insertPlainText(QString::fromLocal8Bit("�����������") + "\n");
	}
	catch (Spinnaker::Exception& e)
	{
		cout << "Error: " << e.what() << endl;
	}
}

//�����ź�
void FLIRVision::GrabNextImageByTrigger(INodeMap& nodeMap, CameraPtr pCam)
{
	cout << "Use the hardware to trigger image acquisition." << endl;
}

//�رմ���ģʽ
void FLIRVision::ResetTrigger(INodeMap& nodeMap)
{
	CEnumerationPtr ptrTriggerMode = nodeMap.GetNode("TriggerMode");
	CEnumEntryPtr ptrTriggerModeOff = ptrTriggerMode->GetEntryByName("Off");
	ptrTriggerMode->SetIntValue(ptrTriggerModeOff->GetValue());
}

//������ȡͼƬ
int FLIRVision::AcquireImages(CameraPtr pCam, INodeMap& nodeMap)
{
	int result = 0;
	cout << endl << endl << "*** IMAGE ACQUISITION ***" << endl << endl;

	//���ô���������ÿ��ͼƬ����
	const unsigned int numtriggerImages = ui.imagetrigger->value();
	const unsigned int numtriggerGroups = ui.grouptrigger->value();

	int imageCnt = 0;
	int group = 1;

	while (1)
	{
		try
		{
			GrabNextImageByTrigger(nodeMap, pCam);
			ImagePtr pResultImage = pCam->GetNextImage(1000);
			ImagePtr convertedImage = pResultImage->Convert(PixelFormat_Mono8, HQ_LINEAR);
			//��������·��
			string file_Name = ".\\triggerimage\\" + to_string(group) + "\\";
			CreateDirectoryU8(file_Name);
			//����ͼƬ
			ostringstream filename;
			filename << file_Name << imageCnt + 1 << ".bmp";
			convertedImage->Save(filename.str().c_str());
			imageCnt++;
			if (imageCnt == numtriggerImages)
			{
				group++;
				if (group == numtriggerGroups + 1)
				{
					break;
				}
				string file_Name = ".\\triggerimage\\" + to_string(group);
				CreateDirectoryU8(file_Name);
				imageCnt = 0;
			}
			pResultImage->Release();
		}
		catch (Spinnaker::Exception& e)
		{
			cout << "Error: " << e.what() << endl;
			result = -1;
		}
		
	}
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("ȡͼ��ɣ���") + QString::number(numtriggerGroups) + QString::fromLocal8Bit("�飬") + QString::fromLocal8Bit("ÿ��ͼƬ��Ϊ") + QString::number(numtriggerImages) + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	pCam->EndAcquisition();
	return result;
}

int FLIRVision::AcquireImagessingle(CameraPtr pCam, INodeMap& nodeMap)
{
	int result = 0;
	cout << endl << endl << "*** IMAGE ACQUISITION ***" << endl << endl;

	//���ô���������ÿ��ͼƬ����
	const unsigned int numtriggerImages = ui.imagetrigger->value();
	const unsigned int group = ui.Grouptriggercount->value();

	int imageCnt = 0;

	while (1)
	{
		try
		{
			GrabNextImageByTrigger(nodeMap, pCam);
			ImagePtr pResultImage = pCam->GetNextImage(1000);
			ImagePtr convertedImage = pResultImage->Convert(PixelFormat_Mono8, HQ_LINEAR);
			//��������·��
			string file_Name = ".\\triggerimage\\" + to_string(group) + "\\";
			CreateDirectoryU8(file_Name);
			//����ͼƬ
			ostringstream filename;
			filename << file_Name << imageCnt + 1 << ".bmp";
			convertedImage->Save(filename.str().c_str());
			imageCnt++;
			if (imageCnt == numtriggerImages)
			{
				break;
			}
			pResultImage->Release();
		}
		catch (Spinnaker::Exception& e)
		{
			cout << "Error: " << e.what() << endl;
			result = -1;
		}

	}
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("ȡͼ���") + QString::fromLocal8Bit("����ͼƬ��Ϊ") + QString::number(numtriggerImages) + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	pCam->EndAcquisition();
	return result;
}
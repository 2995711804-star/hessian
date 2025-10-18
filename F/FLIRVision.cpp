#include "FLIRVision.h"

#include <string>
#ifdef _WIN32
#include <windows.h>
#endif

// 将 UTF-8 std::string 路径转为宽字串并调用 CreateDirectoryW。
// 返回 TRUE 表示创建成功；如果目录已存在也视为成功。
static inline BOOL CreateDirectoryU8(const std::string& utf8_path) {
#ifdef _WIN32
	// 1) 计算需要的宽字符数量（包含终止符）
	int n = MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, nullptr, 0);
	if (n <= 0) return FALSE;

	// 2) 分配并转换
	std::wstring wpath;
	wpath.resize(static_cast<size_t>(n - 1));        // 不包含终止符
	if (n > 1) {
		MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, &wpath[0], n);
	}

	// 3) 调用宽字符版 CreateDirectory
	BOOL ok = ::CreateDirectoryW(wpath.c_str(), nullptr);
	if (!ok) {
		DWORD err = GetLastError();
		if (err == ERROR_ALREADY_EXISTS) return TRUE; // 已存在也算成功
	}
	return ok;
#else
	// 非 Windows 平台（占位，按需实现）
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
		//放大10倍在QSlider中显示
		ui.horizontalSlider_gamma->setValue(v * 100);
	});
	connect(ui.horizontalSlider_gamma, &QSlider::valueChanged, ui.spinBox_gamma, [=](int v)
	{
		//缩小10倍在QDoubleSpinBox中显示
		ui.spinBox_gamma->setValue((double)v / 100);
	});

	connect(ui.Information, SIGNAL(textChanged()), SLOT(slotTextTcpChanged()));
}

FLIRVision::~FLIRVision()
{}

//初始化相机
void FLIRVision::on_Initialize_clicked()
{
	//新建相机系统，用于初始化和管理相机
	system = System::GetInstance();
	//获取相机列表，即检测到所有连接计算机的相机
	camList = system->GetCameras();
	//获取相机数目，并输出显示
	int numCameras = camList.GetSize();
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("：系统初始化，检测到相机个数为：") + QString::number(numCameras) + "\n");
	ui.Information->moveCursor(QTextCursor::End);

	if (numCameras == 0)
	{
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("：未检测到相机") + "\n");
		ui.Information->moveCursor(QTextCursor::End);
		camList.Clear();
		//释放系统
		system->ReleaseInstance();
	}
	//相机实例化，由于只有一个相机，选择第一个相机，因此相机index为0
	pCam = camList.GetByIndex(0);
	//start按钮停用
	ui.Initialize->setDisabled(true);
	//stop按钮启用
	ui.Pause->setDisabled(false);
	//关闭视频流按钮启用
	ui.videostreaming->setDisabled(true);	
	//触发控件在关闭视频流的情况才才能使用
    ui.Trigger->setDisabled(true);
	ui.singleTrigger->setDisabled(true);	
	//q控制跳出循环显示，用于暂停视频流
	q = 0;
	//判断图像是否拍摄
	on_Piccount_valueChanged();
	//初始化相机参数
	Configure(pCam);
	//窗口显示视频流
	ImshowCamera();
}

//初始化相机设置
void FLIRVision::Configure(CameraPtr pCam)
{
	//获取相机的设备映射点
	INodeMap& nodeMapTLDevice = pCam->GetTLDeviceNodeMap();
	//初始化相机
	pCam->Init();
	//获取相机的节点映射
	INodeMap& nodeMap = pCam->GetNodeMap();
	try
	{
		//从相机的节点映射中获取了名为 "AcquisitionMode" 的节点并将其赋值给名为 ptrAcquisitionMode 的枚举指针
		CEnumerationPtr ptrAcquisitionMode = nodeMap.GetNode("AcquisitionMode");
		//从"AcquisitionMode"节点的枚举值中获取了名为"Continuous"的枚举条目并赋值给"ptrAcquisitionModeContinuous"枚举条目指针
		CEnumEntryPtr ptrAcquisitionModeContinuous = ptrAcquisitionMode->GetEntryByName("Continuous");
		//获取"Continuous"的值，并赋值给acquisitionModeContinuous
		const int64_t acquisitionModeContinuous = ptrAcquisitionModeContinuous->GetValue();
		//将相机的采集模式设置为连续模式
		ptrAcquisitionMode->SetIntValue(acquisitionModeContinuous);

		//关闭自动曝光，初始曝光值设置未50000
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
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("：自动曝光关闭") + "\n"); 
		ui.Information->moveCursor(QTextCursor::End);

		//初始化关闭触发功能
		CEnumerationPtr ptrTriggerMode = nodeMap.GetNode("TriggerMode");
		CEnumEntryPtr ptrTriggerModeOff = ptrTriggerMode->GetEntryByName("Off");
		ptrTriggerMode->SetIntValue(ptrTriggerModeOff->GetValue());
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("：触发功能关闭") + "\n");
		ui.Information->moveCursor(QTextCursor::End);

		//关闭自动增益，初始增益1
		CEnumerationPtr gainAuto = nodeMap.GetNode("GainAuto");
		gainAuto->SetIntValue(gainAuto->GetEntryByName("Off")->GetValue());
		CFloatPtr gainValue = nodeMap.GetNode("Gain");
		gainValue->SetValue(10.5);
		ui.spinBox_gain->setValue(1);
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("：自动增益关闭") + "\n");
		ui.Information->moveCursor(QTextCursor::End);

		//初始Gamma1
		CFloatPtr gamma = nodeMap.GetNode("Gamma");
		gamma->SetValue(1);
		ui.spinBox_gamma->setValue(1);
		ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("：当前Gamma值为1") + "\n");
		ui.Information->moveCursor(QTextCursor::End);

	}
	catch (Spinnaker::Exception& e)
	{
		cout << "Error: " << e.what() << endl;
	}
}

//实时显示视频流
void FLIRVision::ImshowCamera()
{
	//开始相机的图像采集过程，从此开始相机会持续获取图像
	pCam->BeginAcquisition();

	while (true)
	{
		//创建图像指针并获取下一帧图像
		ImagePtr pResultImage = pCam->GetNextImage();
		//图像宽度
		const size_t width = pResultImage->GetWidth();
		//图像高度
		const size_t height = pResultImage->GetHeight();
		//图像格式转换
		ImagePtr rgbImage = pResultImage->Convert(PixelFormat_BGR8);
		void* image_data = rgbImage->GetData();
		unsigned int stride = rgbImage->GetStride();
		Mat current_frame = cv::Mat(height, width, CV_8UC3, image_data, stride);
		//Mat display_frame = cv::Mat();
		//cv::resize(current_frame, display_frame, Size(width, height));
		QImage img(current_frame.data, current_frame.cols, current_frame.rows, QImage::Format_RGB888);
		ui.camera->setPixmap(QPixmap::fromImage(img));
		cv::waitKey(1);
		//释放图像指针
		pResultImage->Release();
		if (q == 1)
		{
			break;
		}
	}
	pCam->EndAcquisition();// 结束相机的图像采集
}

//打开视频流
void FLIRVision::on_videostreaming_clicked()
{
	q = 0;
	ui.Pause->setDisabled(false);
	ui.videostreaming->setDisabled(true);
	ui.Trigger->setDisabled(true);
	ui.singleTrigger->setDisabled(true);
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("开启视频流") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	ImshowCamera();
}

//暂停获取图像流
void FLIRVision::on_Pause_clicked()//关闭相机
{
	q = 1;
	ui.Initialize->setDisabled(false);
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("关闭视频流") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	ui.Pause->setDisabled(true);
	ui.videostreaming->setDisabled(false);
	////触发控件在关闭视频流的情况才才能使用
	ui.Trigger->setDisabled(false);
	ui.singleTrigger->setDisabled(false);
}

//手动调节曝光
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

//手动调节增益
void FLIRVision::on_spinBox_gain_valueChanged()
{
	double gainval = ui.spinBox_gain->value();
	INodeMap& nodeMap = pCam->GetNodeMap();

	CEnumerationPtr gainAuto = nodeMap.GetNode("GainAuto");
	gainAuto->SetIntValue(gainAuto->GetEntryByName("Off")->GetValue());

	CFloatPtr gainValue = nodeMap.GetNode("Gain");
	gainValue->SetValue(gainval);
}

//手动调节Gamma
void FLIRVision::on_spinBox_gamma_valueChanged()
{
	double gammaval = ui.spinBox_gamma->value();
	INodeMap& nodeMap = pCam->GetNodeMap();

	CFloatPtr gamma = nodeMap.GetNode("Gamma");
	gamma->SetValue(gammaval);
}

//捕捉图像
void FLIRVision::on_Catchimages_clicked()
{
	//创建图像指针并获取下一帧图像
	ImagePtr CatchImage = pCam->GetNextImage();
	//图像宽度
	const size_t width = CatchImage->GetWidth();
	//图像高度
	const size_t height = CatchImage->GetHeight();
	//图像格式转换
	ImagePtr rgbImage = CatchImage->Convert(PixelFormat_Mono8);
	unsigned int rowBytes = (double)rgbImage->GetImageSize() / (double)height;
	//将图像转换为Mat格式+
	frame = Mat(height, width, CV_8UC1, rgbImage->GetData(), rowBytes);
	//获取组数值
	int group = ui.Groupcount->value();
	//获取图像数值
	int i = ui.Piccount->value();
	//创建组
	string file_Name = ".\\image\\" + to_string(group);
	//std::wstring file_Name = L".\\image\\" + std::to_wstring(group);


	//图片保存位置
	string img_Name = ".\\image\\" + to_string(group) + "\\" + to_string(i) + ".bmp";
	//创建文件夹
	BOOL flag = CreateDirectoryU8(file_Name);
	imwrite(img_Name, frame);
	i++;
	ui.Piccount->setValue(i);
	CatchImage->Release();//释放图像指针
}

//判断图像是否拍摄
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
		ui.capturestate->setText(QString::fromLocal8Bit("未拍摄"));
		ui.capturestate->setStyleSheet("color:red");
	}
	else if (flag == 1)
	{
		ui.capturestate->setText(QString::fromLocal8Bit("已拍摄"));
		ui.capturestate->setStyleSheet("color:green");
	}
}

//改变组数图像转为改组第一张
void FLIRVision::on_Groupcount_valueChanged()
{
	on_Piccount_valueChanged();
	ui.Piccount->setValue(1);
}

//退出界面
void FLIRVision::on_Exit_clicked()
{
	//关闭当前界面
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("系统关闭") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	this->close();
}

//查看图片
void FLIRVision::on_Image_clicked()//查看采集图片
{
	QDesktopServices::openUrl(QUrl::fromLocalFile(".\\image\\"));
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("打开采集文件夹") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
}

//--------触发--------//
void FLIRVision::on_Trigger_clicked()
{
	//获取相机的节点映射
	INodeMap& nodeMap = pCam->GetNodeMap();
	on_ConfigureTrigger(nodeMap);
	AcquireImages(pCam, nodeMap);
	ResetTrigger(nodeMap);
}

void FLIRVision::on_singleTrigger_clicked()
{
	//获取相机的节点映射
	INodeMap& nodeMap = pCam->GetNodeMap();
	on_ConfigureTrigger(nodeMap);
	AcquireImagessingle(pCam, nodeMap);
	ResetTrigger(nodeMap);
}

//查看触发图片
void FLIRVision::on_Triggerimage_clicked()//查看采集图片
{
	QDesktopServices::openUrl(QUrl::fromLocalFile(".\\triggerimage\\"));
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("打开触发文件夹") + "\n");
	ui.Information->moveCursor(QTextCursor::End);
}

void FLIRVision::on_ConfigureTrigger(INodeMap& nodeMap)
{
	try
	{
		//关闭触发模式，配置触发时无论选择何种触发都要将触发模式关闭
		CEnumerationPtr ptrTriggerMode = nodeMap.GetNode("TriggerMode");
		CEnumEntryPtr ptrTriggerModeOff = ptrTriggerMode->GetEntryByName("Off");
		ptrTriggerMode->SetIntValue(ptrTriggerModeOff->GetValue());

		CEnumerationPtr ptrTriggerSelector = nodeMap.GetNode("TriggerSelector");
		CEnumEntryPtr ptrTriggerSelectorFrameStart = ptrTriggerSelector->GetEntryByName("FrameStart");
		ptrTriggerSelector->SetIntValue(ptrTriggerSelectorFrameStart->GetValue());

		//选择触发源硬触发Software，软触发Line0，Line2，Line3
		CEnumerationPtr ptrTriggerSource = nodeMap.GetNode("TriggerSource");
	    CEnumEntryPtr ptrTriggerSourceHardware = ptrTriggerSource->GetEntryByName("Line3");
	    ptrTriggerSource->SetIntValue(ptrTriggerSourceHardware->GetValue());
	    cout << "触发源选择Line3" << endl;

		CEnumEntryPtr ptrTriggerModeOn = ptrTriggerMode->GetEntryByName("On");
		ptrTriggerMode->SetIntValue(ptrTriggerModeOn->GetValue());
		pCam->BeginAcquisition();
		ui.Information->insertPlainText(QString::fromLocal8Bit("触发配置完成") + "\n");
	}
	catch (Spinnaker::Exception& e)
	{
		cout << "Error: " << e.what() << endl;
	}
}

//触发信号
void FLIRVision::GrabNextImageByTrigger(INodeMap& nodeMap, CameraPtr pCam)
{
	cout << "Use the hardware to trigger image acquisition." << endl;
}

//关闭触发模式
void FLIRVision::ResetTrigger(INodeMap& nodeMap)
{
	CEnumerationPtr ptrTriggerMode = nodeMap.GetNode("TriggerMode");
	CEnumEntryPtr ptrTriggerModeOff = ptrTriggerMode->GetEntryByName("Off");
	ptrTriggerMode->SetIntValue(ptrTriggerModeOff->GetValue());
}

//触发获取图片
int FLIRVision::AcquireImages(CameraPtr pCam, INodeMap& nodeMap)
{
	int result = 0;
	cout << endl << endl << "*** IMAGE ACQUISITION ***" << endl << endl;

	//设置触发组数和每组图片数量
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
			//创建组数路径
			string file_Name = ".\\triggerimage\\" + to_string(group) + "\\";
			CreateDirectoryU8(file_Name);
			//保存图片
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
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("取图完成，共") + QString::number(numtriggerGroups) + QString::fromLocal8Bit("组，") + QString::fromLocal8Bit("每组图片数为") + QString::number(numtriggerImages) + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	pCam->EndAcquisition();
	return result;
}

int FLIRVision::AcquireImagessingle(CameraPtr pCam, INodeMap& nodeMap)
{
	int result = 0;
	cout << endl << endl << "*** IMAGE ACQUISITION ***" << endl << endl;

	//设置触发组数和每组图片数量
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
			//创建组数路径
			string file_Name = ".\\triggerimage\\" + to_string(group) + "\\";
			CreateDirectoryU8(file_Name);
			//保存图片
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
	ui.Information->insertPlainText(time_str + QString::fromLocal8Bit("取图完成") + QString::fromLocal8Bit("该组图片数为") + QString::number(numtriggerImages) + "\n");
	ui.Information->moveCursor(QTextCursor::End);
	pCam->EndAcquisition();
	return result;
}
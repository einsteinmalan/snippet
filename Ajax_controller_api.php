<?php

namespace App\Http\Controllers\Frontend;

use App\Http\Controllers\Controller;
use App\User;
use App\Models\Student;
use App\Models\StudentFavourites;
use App\Models\Course;
use App\Models\Tutor;
use App\Models\School;
use App\Models\Classes;
use App\Models\Department;
use App\Models\DepartmentClass;
use App\Models\SchoolCategory;
use Illuminate\Http\Request;
use DB;
use Carbon\Carbon;
use Exception;
use App\Helpers\SiteHelpers;

class AjaxController extends Controller
{
    /**
     * Create a new controller instance.
     *
     * @return void
     */
    public function __construct()
    {
        //$this->middleware('auth');
    }

    /**
     * ::Created_Alex:
     * Send Otp code to user mobile number
     * return status true / false with error message
     */
    public function sendOtp(Request $request)
    {
        if ($request->isMethod('post')) {


            if (empty($request->input('user_id'))) {
                $res['status'] = false;
                $res['message'] = "User not found";
            } else {

                $user_id = $request->input('user_id');
                $sessionUser = User::find($request->input('user_id'));
                $userRole = $sessionUser->userRole->role->slug;

                $res['status'] = false;
                $res['message'] = null;

                $data = $request->all();

                if ($data['type'] == 'send-otp') {
                    try {
                        $otp = mt_rand(10000, 99999);

                        //::Created_fred:change mobile number
                        if ($data['mobile_number_type'] == "new") {

                            $student_mobile_exists = Student::where(['mobile' => $data['mobile']])->count();
                            if ($student_mobile_exists > 0) {
                                $res['status'] = false;
                                $res['message'] = "This mobile number already registered.";
                                return json_encode($res);
                            } else {
                                if ($userRole == 'student') {
                                    Student::where(["user_id" => $sessionUser->id, 'mobile' => $data['old_mobile_number']])->update(array('mobile' => $data['mobile']));
                                } else if ($userRole == 'student') {
                                    Tutor::where(["user_id" => $sessionUser->id, 'mobile' => $data['old_mobile_number']])->update(array('mobile' => $data['mobile']));
                                }
                            }
                        }

                        if ($userRole == 'student') {
                            $student = Student::where(['user_id' => $sessionUser->id, 'mobile' => $data['mobile']])->first();
                        } else if ($userRole == 'tutor') {
                            $student = Tutor::where(['user_id' => $sessionUser->id, 'mobile' => $data['mobile']])->first();
                        }
                        if ($student) {
                            //$student->otp = $otp;
                            //$student->save();
//                            if ($data['mobile_number_type'] == "new") {
//                                SiteHelpers::updateOtp($student->user_id, $data['phone_code'], $data['mobile'], $otp, $data['old_mobile_number']);
//                            } else {
//                                SiteHelpers::updateOtp($student->user_id, $data['phone_code'], $data['mobile'], $otp);
//                            }
                            //$otpSend = SiteHelpers::sendOtpToUser($data['country-code'], $data['mobile_number'], $otp);

                            /* Below code for send otp to student */
                            //$sendOtp = SiteHelpers::sendOtpToUser($data['phone_code'], $data['mobile'], $otp);
                            /* Send verification to student or  tutor using TWILo */
                            $vsid = SiteHelpers::sendOtpUsingTwilio($student->user_id, $data['phone_code'], $data['mobile']);

                            if(!empty($vsid)){
                                $res['status'] = true;
                                $res['message'] = "Verification code successfully sent on your mobile number.";
                            } else {
                                $res['status'] = false;
                                $res['message'] = "Unable to send verification code";
                            }
                            

//                            $sendOtp = json_decode(json_encode($sendOtp), true);
//                            //echo "<pre>"; print_r($sendOtp); exit;
//                            if (isset($sendOtp['messages']) && array_key_exists('error-text', $sendOtp['messages'][0]) && $sendOtp['messages'][0]['status'] != 0) {
//                                $res['status'] = false;
//                                $res['message'] = $sendOtp['messages'][0]['error-text'];
//                            } else {
//                                $res['status'] = true;
//                                $res['message'] = "Verification code successfully sent on your mobile number.";
//                            }
                        } else {
                            $res['status'] = false;
                            $res['message'] = "Wrong registered mobile number";
                        }
                    } catch (Exception $e) {
                        $res['status'] = false;
                        $res['message'] = $e->getMessage();
                    }

                    return json_encode($res);
                }
            }
        } else {
            return "Invalide request";
        }
    }

    /**
     * ::Created_fred: Verify user otp
     * return status true / false with error message
     */
    public function verifyOtp(Request $request)
    {
        if ($request->isMethod('post')) {
            $res['status'] = false;
            $res['message'] = null;

            $data = $request->all();

            if ($data['type'] == 'verify-otp') {
                try {

                    $user_id = $request->all('user_id');
                    
                    if ($user_id) {
                        
                        $otpdetails = DB::table("mobile_verifications")
                                            ->where('user_id', $user_id)
                                            ->where('mobile', $request->all('mobile'))
                                            ->orderBy('id','desc')->first();
                       
                        if(!empty($otpdetails->vsid)){ 

							/* $diffMinutes = SiteHelpers::createdAtdiffInMinutes($otpdetails->created_at);
							$checkOtpTime = SiteHelpers::validOtpTime($diffMinutes);
							
							if($checkOtpTime){ */
								
                            $vsid = $otpdetails->vsid;
                            $code = $request->input('otp');
                            
                            $status = SiteHelpers::verifyOtpUsingTwilio($vsid, $code);
                            
                            if($status == 'approved') {
                                User::where('id', $user_id)->update(['mobile_verified_at' => Carbon::now()]);
                                $res['status'] = true;
                                $res['message'] = "Verification code verified successfully.";
                            } else {
                                $res['status'] = false;
                                $res['message'] = "Wrong verification code.";
                            }
							/* }else{
								
								$res['status'] = false;
                                $res['message'] = "Your OTP expired.";
							} */
                            
                        } else {
                            $res['status'] = false;
                            $res['message'] = "Wrong verification code.";
                        }
                    } else {                        
                        $res['status'] = false;
                        $res['message'] = "Wrong registered mobile number.";
                        //return redirect()->route('registerStep', 2)->withErrors($validator)->withInput();
                    }
                } catch (Exception $e) {
                    $res['status'] = false;
                    $res['message'] = $e->getMessage();
                }

                return json_encode($res);
            }
        } else {
            return "Invalide request";
        }
    }

    /** 
     * ::Created_Alex:
     * Search school as per institution
     * return status true / false with error message
     */
    public function searchschool(Request $request)
    {
        $data = $request->all();
        //$res['status'] = false;
        //$res['school_data'] = null;

        //$schools = School::where('status', 1)->where('school_name', 'like', $data['keyword'] . '%');
        $schools = School::where('school_name', 'like', '%' . $data['keyword'] . '%');
        //if(isset($data['category_id']) && !empty($data['category_id'])) {
        $schools = $schools->where('school_category', $data['category_id']);
        //}
        $schools = $schools->select('id', 'school_name')->get();
        if (!$schools->isEmpty()) {

            return view('auth.forms.searchschool', compact('schools'));
        } else {
            echo "Invalid School Name!";
        }

        //return json_encode($res);
        //return view('auth.forms.searchschool', compact('schools'));
    }

    /**
     * ::Created_Alex:
     * Search school as per institution
     * return status true / false with error message
     */
    public function schoolcourses(Request $request)
    {
        $data = $request->all();
        $optionName = "Course";

        if (!empty($request->optionName)) {
            $optionName = $request->optionName;
        }
        if ($request->listData == 'department') {
            $schoolcourses = Department::where('status', 1)->where('school_id', $data['school_id'])->select('id', 'name')->get();
        } else {
            $schoolcourses = Course::where('status', 1)->where('school_id', $data['school_id'])->select('id', 'name')->get();
        }

        return view('auth.forms.schoolcourses', compact('schoolcourses', 'optionName'));
    }

    /**
     * Classes list by ajax
     */
    public function schoolclasses(Request $request)
    {
        $data = $request->all();
        $course_id = $data['course_id'];

        if ($data['category_id'] == School::BASIC_SCHOOL) {
            if (empty($course_id) && !empty($data['school_id'])) {
                $school = School::find($data['school_id']);
                $schoolcourses = Course::where('school_id', $school->id)->first();
                if (!empty($schoolcourses->id)) {
                    $course_id = $schoolcourses->id;
                }
            }
        }

        $schoolclasses = Classes::where('status', 1)->where('course_id', $course_id)->select('id', 'class_name')->get();

        return view('auth.forms.schoolclasses', compact('schoolclasses'));
    }

}

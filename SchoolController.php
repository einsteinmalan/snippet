<?php

namespace App\Http\Controllers\backend;

use App\Models\Topic;
use App\Models\Tutor;
use App\Models\Video;
use App\Models\Course;
use App\Models\Period;
use App\Models\Region;
use App\Models\School;
use App\Models\Classes;
use App\Models\Student;
use App\Models\Subject;
use App\Models\District;
use App\Models\Department;
use App\Helpers\SiteHelpers;
use Illuminate\Http\Request;
use App\Models\SchoolCategory;
use App\Models\SchoolSemester;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Redirect;
use Illuminate\Support\Facades\Validator;

class SchoolController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index()
    {
        $query = School::where('id','<>',0);
        //Check for the user profile
        if(Auth::user()->hasRole('school')){
            $profile = Auth::user()->profile;
            if(isset($profile->school_id)){
                $query = $query->where('id','=',$profile->school_id);
            }
        }

        $schools = $query->orderBy('id', 'desc')->get();


        return view('backend.school.index', compact('schools'));
    }

    /**
     *   Register Region\ District
     *
     *
     */
    public function getStates(Region $region)
    {
        return $region->states()->select('id', 'name')->get();
    }




    /**
     * Show the form for creating a new resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function create()
    {
		$query = SchoolCategory::where('status','=',1);

		if(Auth::user()->hasRole('school')){
            return redirect()->route('backend.dashboard');
        }

        $categories = $query->orderBy('name')->get();


        //collect Regions & District from db

      //  $regions = Region::all();
        $countries = DB::table("regions")->pluck("name","id");
        $districts = District::all();



       // return view('backend.school.create', compact('categories'));
       return view('backend.school.create', compact('categories','countries'));
    }

    //::Created_fred: Get list of Districts
    public function getStateList(Request $request)
    {
        $states = DB::table("districts")
        ->where("region_id",$request->country_id)
        ->pluck("name","id");
        return response()->json($states);
    }



	function total_featured_school() {

		$featured_school_limit = config("constants.FEATURED_SCHOOL_LIMIT");
		$total_featured_count = School::where('status','=',1)->where('featured', 1)->where('deleted_at', NULL)->count();

		if($total_featured_count<$featured_school_limit) {
			return false;
		} else {
			return true;
		}

	}

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
		$data = $request->all();

        $featured_limit_reached = $this->total_featured_school();

		if($featured_limit_reached && $request->input('featured') !== null) {
			$featured_school_limit = config("constants.FEATURED_SCHOOL_LIMIT");
			$error_msg = "You have reached your maximum limit ".$featured_school_limit." of featured school allowed";
			return Redirect::back()
                            ->withErrors(['error'=>$error_msg]) // send back all errors to the form
                            ->withInput();
		}

		$school_category = $request->input('school_category');

        $validator = Validator::make($request->all(), [
                    'school_name' => [
                        'required',
                        'max:180',
                        Rule::unique('schools')->where(function ($query) use($school_category) {
                                    return $query->where('school_category', $school_category);
                                })
                    ],
        ]);

        // if the validator fails, redirect back to the form
        if ($validator->fails()) {
            return Redirect::back()
                            ->withErrors($validator) // send back all errors to the form
                            ->withInput();
        }

        //Persist the school in the database
        //form data is available in the request object
        $school = new School();
        //input method is used to get the value of input with its
        //name specified
        $school->school_name = $request->input('school_name');
        $school->short_name = $request->input('short_name');
        $school->school_category = $request->input('school_category');
        $school->description = $request->input('description');

        $school->school_code = $request->input('school_code');
        $school->school_location = $request->input('school_location');
        $school->region_id = $request->input('region');
        $school->district_id = $request->input('district');
        $school->school_gender = $request->input('school_gender');
        $school->school_sector  = $request->input('school_sector');

		if(Auth::user()->hasRole('admin') || Auth::user()->hasRole('subadmin')){
			$school->theme = $request->input('theme');
			$school->status = ($request->input('status') !== null) ? $request->input('status') : 0;
			$school->featured = ($request->input('featured') !== null) ? $request->input('featured') : 0;
			$school->restrict_to_student = 	 isset($data['restrict_to_student']) ? $data['restrict_to_student'] : 0;
			$school->student_limit = 	 (isset($data['student_limit']) && !empty($data['student_limit']) && isset($data['restrict_to_student'])) ? $data['student_limit'] : 0;
		}

		$school->is_locked = ($request->input('is_locked') !== null) ? $request->input('is_locked') : 0;

        //::Created_fred: Below code for save school logo

        if ($request->hasFile('school_logo')) {

            $validator = Validator::make($request->all(), [
                        'school_logo' => 'image|mimes:jpeg,png,jpg,gif|max:2048',
                            ], [
                        'school_logo.max' => 'The school logo may not be greater than 2 mb.',
                            ]
            );

            if ($validator->fails()) {
                return redirect()->route('backend.school.create')->withErrors($validator)->withInput();
            }

            $destinationPath = public_path('/uploads/schools/');
            $newName = '';
            $fileName = $request->all()['school_logo']->getClientOriginalName();
            $file = request()->file('school_logo');
            $fileNameArr = explode('.', $fileName);
            $fileNameExt = end($fileNameArr);
            $newName = date('His') . rand() . time() . '__' . $fileNameArr[0] . '.' . $fileNameExt;

            $file->move($destinationPath, $newName);

            //::Created_fred: Below commented code for resize the image **//

            /* $user_config = json_decode(options['user'],true);

              $img = Image::make(public_path('/uploads/users/'.$newName));
              $img->resize($user_config['image']['width'], $user_config['image']['height']);
              $img->save(public_path('/uploads/users/'.$newName)); */

            $imagePath = 'uploads/schools/' . $newName;
            $school->logo = $newName;
        }



        $school->save(); //persist the data

		//add one basic education course when select basic school
		if(isset($school->id) && $school->school_category == config("constants.BASIC_SCHOOL")) {
			$course = new Course();
			$course->name = "Basic Education";
			$course->school_id = $school->id;
			$course->description = "Basic Education";
			$course->save(); //persist the data
		}


        return redirect()->route('backend.schools')->with('success', 'School Created Successfully');
    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        if(!Auth::user()->hasAccessToSchool($id)){
            return redirect()->route('backend.dashboard');
        }

        $school = School::findOrFail($id);
        $semester_labels = $school->semesterNameArray();
        $school_semesters = SchoolSemester::where('school_id', $id)->get();
        $region = School::find($id)->region();

        $semesters = [];
        foreach ($semester_labels as $key => $name) {
            $semesters[$key] = [
                'name' => $name,
                'date_begin' => '',
                'date_end' => '',
                'status' => false
            ];
        }
        foreach ($school_semesters as $semester) {
            $semesters[$semester->semester]['date_begin'] = $semester->date_begin;
            $semesters[$semester->semester]['date_end'] = $semester->date_end;
            $semesters[$semester->semester]['status'] = true;
        }


        $courses = Course::where('school_id', $id)->orderBy('id', 'desc')->get();
        $departments = Department::where('school_id', $id)->orderBy('id', 'desc')->get();
        $region = School::find($id)->region;
        $district = District::all();

		$department_count = SiteHelpers::dashboard_resource_count('departments', $id);
		$courses_count = SiteHelpers::dashboard_resource_count('courses', $id);
		$classes_count = SiteHelpers::dashboard_resource_count('classes', $id);
		$videos_count = SiteHelpers::dashboard_resource_count('videos', $id);
        $student_count = SiteHelpers::dashboard_resource_count('students', $id);
        $tutor_count = SiteHelpers::dashboard_resource_count('tutors', $id);

        return view('backend.school.show', compact('school', 'courses', 'departments', 'semesters', 'department_count', 'courses_count', 'classes_count', 'videos_count', 'student_count', 'tutor_count','region','district'));
    }

    /**
     * ::Created_fred:Save semester and term info.
     * @return \Illuminate\Http\Response
     */
    public function savesemester(Request $request)
    {
        $school_id = $request->school;

		if(!Auth::user()->hasAccessToSchool($school_id)){
            return redirect()->route('backend.dashboard');
        }

        $school = School::find($school_id);
        $semester_labels = $school->semesterNameArray();

        $validator = Validator::make($request->all(), [
                    'check1' => 'required',
                    'start_date1' => 'required_with:check1',
                    'end_date1' => 'nullable|required_with:check1|after:start_date1',
                    'start_date2' => 'required_with:check2',
                    'end_date2' => 'nullable|required_with:check2|after:start_date2',
                    'start_date3' => 'required_with:check3',
                    'end_date3' => 'nullable|required_with:check3|after:start_date3',
                ], [
                    'check1.required' => 'Please choose at least ' . $semester_labels[1] . '.',
                    'start_date1.required_with' => 'The Start date field is required for ' . $semester_labels[1] . '.',
                    'end_date1.required_with' => 'The End date field is required for ' . $semester_labels[1] . '.',
                    'start_date2.required_with' => 'The Start date field is required for ' . $semester_labels[2] . '.',
                    'end_date2.required_with' => 'The End date field is required for ' . $semester_labels[2] . '.',
                    'start_date3.required_with' => 'The Start date field is required for ' . $semester_labels[3] . '.',
                    'end_date3.required_with' => 'The End date field is required for ' . $semester_labels[3] . '.',
                    'end_date1.after' => 'The End date must be a date after Start date for ' . $semester_labels[1] . '.',
                    'end_date2.after' => 'The End date must be a date after Start date for ' . $semester_labels[2] . '.',
                    'end_date3.after' => 'The End date must be a date after Start date for ' . $semester_labels[3] . '.'
                ]
        );


        if ($validator->fails()) {
            return redirect()->route('backend.school.show', $request->school)->withErrors($validator)->withInput();
        }

        //delete record before update the new
        if (!empty($request->input('school'))) {
            SchoolSemester::where('school_id', $request->input('school'))->delete();
        }

        $semester_options = [];
        foreach ($semester_labels as $key => $label){
            if (!empty($request->input('check' . $key))) {
                $semester_options[] = $request->input('check' . $key);

            }
        }

        foreach ($semester_options as $semester_key) {
            $schoolsemester = new SchoolSemester();
            $schoolsemester->school_id = $request->input('school');
            $schoolsemester->category_id = $school->school_category;
            $schoolsemester->semester = $semester_key;
            $schoolsemester->date_begin = $request->input("start_date" . $semester_key);
            $schoolsemester->date_end = $request->input("end_date" . $semester_key);
            $schoolsemester->save();
        }

        return redirect()->route('backend.school.show', $request->input('school'))->with('success', 'Semester Information Saved Successfully');
    }

    /**
     * Show the form for editing the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function edit($id)
    {
		if(Auth::user()->hasRole('school')){
            return redirect()->route('backend.dashboard');
        }

        //Find the school
        $school = School::find($id);
        $categories = SchoolCategory::where('status', 1)->get();


        $countries = DB::table("regions")->pluck("name","id");
        $districts = DB::table("districts")->pluck("name","id");

      //  $districts = District::all();

        return view('backend.school.edit', compact('school', 'categories','countries','districts'));
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(Request $request, $id)
    {
		$data = $request->all();
		$featured_limit_reached = $this->total_featured_school();

		if($featured_limit_reached && $request->input('featured') !== null) {
			$featured_school_limit = config("constants.FEATURED_SCHOOL_LIMIT");
			$error_msg = "You have reached your maximum limit ".$featured_school_limit." of featured school allowed";
			return Redirect::back()
                            ->withErrors(['error'=>$error_msg]) // send back all errors to the form
                            ->withInput();
		}


        $school_category = $request->input('school_category');

        $validator = Validator::make($request->all(), [
                    'school_name' => [
                        'required',
                        'max:180',
                        Rule::unique('schools')->where(function ($query) use($school_category, $id) {
                                    return $query->where('school_category', $school_category)->where('id', '<>', $id);
                                })
                    ],
        ]);

        // if the validator fails, redirect back to the form
        if ($validator->fails()) {
            return Redirect::back()
                            ->withErrors($validator) // send back all errors to the form
                            ->withInput();
        }

        //Retrieve the school and update
        $school = School::find($id);

        $regions = DB::table("regions")->pluck("name","id");
        $districts = DB::table("districts")->pluck("name","id");
        //echo "<pre>"; print_r($school); exit;
        $school->school_name = $request->input('school_name');
        $school->short_name = $request->input('short_name');
        // $school->school_category = $request->input('school_category');
        $school->description = $request->input('description');

        $school->school_code = $request->input('school_code');
        $school->school_location = $request->input('school_location');
        $school->region_id = $request->input('region');
        $school->district_id = $request->input('district');
        $school->school_gender = $request->input('school_gender');
        $school->school_sector  = $request->input('school_sector');

		if(Auth::user()->hasRole('admin') || Auth::user()->hasRole('subadmin')){
			$school->theme = $request->input('theme');
			$school->status = ($request->input('status') !== null) ? $request->input('status') : 0;
			$school->featured = ($request->input('featured') !== null) ? $request->input('featured') : 0;
			$school->restrict_to_student = 	 isset($data['restrict_to_student']) ? $data['restrict_to_student'] : 0;
			$school->student_limit = 	 (isset($data['student_limit']) && !empty($data['student_limit']) && isset($data['restrict_to_student'])) ? $data['student_limit'] : 0;
		}

		$school->is_locked = ($request->input('is_locked') !== null) ? $request->input('is_locked') : 0;

        if ($request->hasFile('school_logo')) {

            $validator = Validator::make($request->all(), [
                        'school_logo' => 'image|mimes:jpeg,png,jpg,gif|max:2048',
                            ], [
                        'school_logo.max' => 'The school logo may not be greater than 2 mb.',
                            ]
            );

            if ($validator->fails()) {
                return redirect()->route('backend.school.edit', $id)->withErrors($validator)->withInput();
            }

            $destinationPath = public_path('/uploads/schools/');
            $newName = '';
            $fileName = $request->all()['school_logo']->getClientOriginalName();
            $file = request()->file('school_logo');
            $fileNameArr = explode('.', $fileName);
            $fileNameExt = end($fileNameArr);
            $newName = date('His') . rand() . time() . '__' . $fileNameArr[0] . '.' . $fileNameExt;

            $file->move($destinationPath, $newName);

            //::Created_fred: Below commented code for resize the image

            /* $user_config = json_decode(options['user'],true);

              $img = Image::make(public_path('/uploads/users/'.$newName));
              $img->resize($user_config['image']['width'], $user_config['image']['height']);
              $img->save(public_path('/uploads/users/'.$newName)); */

            $oldImage = public_path('/uploads/schools/' . $school->logo);
            if (!empty($school->logo) && file_exists($oldImage)) {
                unlink($oldImage);
            }

            $imagePath = 'uploads/schools/' . $newName;
            $school->logo = $newName;
        }


        $school->save(); //persist the data
        return redirect()->route('backend.schools')->with('success', 'School Information Updated Successfully');
    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
		if(Auth::user()->hasRole('school')){
            return redirect()->route('backend.dashboard');
        }

        $school = School::find($id);

		//delete all child records.
		//delete school
		if(isset($school->id) && !empty($school->id)) {

			$departments = Department::where('school_id', $school->id)->select('id')->get();
			//delete department
			foreach($departments as $department) {
				if(isset($department->id) && !empty($department->id))
				$department->delete();
			}

			$courses = Course::where('school_id', $school->id)->select('id')->get();
			//delete course
			foreach($courses as $course) {
				if(isset($course->id) && !empty($course->id)){

					$classes = Classes::where('course_id', $course->id)->select('id')->get();

					foreach($classes as $class) {
						if(isset($class->id) && !empty($class->id)) {
							$subjects = Subject::where('class_id', $class->id)->select('id')->get();

							foreach($subjects as $subject) {
								if(isset($subject->id) && !empty($subject->id)) {

									$topics = Topic::where('subject_id', $subject->id)->select('id')->get();

									foreach($topics as $topic) {
										if(isset($topic->id) && !empty($topic->id))
										$topic->delete();
									}

									$subject->delete();
								}
							}

							$periods = Period::where('class_id', $class->id)->select('id')->get();

							foreach($periods as $period) {
								if(isset($period->id) && !empty($period->id))
								$period->delete();
							}

							$class->delete();
						}
					}
					$course->delete();
				}
			}

			$videos = Video::where('school_id', $school->id)->select('id')->get();
			foreach($videos as $video) {
				if(isset($video->id) && !empty($video->id))
				$video->delete();
			}

			$tutors = Tutor::where('school_id', $school->id)->select('id')->get();
			foreach($tutors as $tutor) {
				if(isset($tutor->id) && !empty($tutor->id))
				$tutor->delete();
			}

			$students = Student::where('school_id', $school->id)->select('id')->get();
			foreach($students as $student) {
				if(isset($student->id) && !empty($student->id))
				$student->delete();
			}


		}

		$school->delete();
        return redirect()->route('backend.schools')->with('success', 'School Deleted Successfully');
    }

}

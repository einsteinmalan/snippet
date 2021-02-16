<?php

namespace App\Http\Controllers\backend;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Subject;
use App\Models\Topic;
use App\Models\Classes;
use App\Models\Course;
use App\Models\School;
use App\Models\SchoolCategory;
use App\Models\Department;
use Illuminate\Validation\Rule;
use Validator;
use Illuminate\Support\Facades\Redirect;
use Auth;

class TopicController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index()
    {
        if (Auth::user()->hasRole('school')) {
            return redirect()->route('backend.dashboard');
        }

        $query = School::where('status', '=', 1);

        if (Auth::user()->hasRole('school')) {
            $profile = Auth::user()->profile;
            if (isset($profile->school_id)) {
                $school_id = $profile->school_id;
                $query = $query->where('id', '=', $school_id);
            }
        }

        $schools = $query->orderBy('school_name')
                ->pluck('school_name', 'id');

        //get all topics
        $topics = Topic::orderBy('id', 'desc')->get();

        return view('backend.topics.index', compact('topics', 'schools'));
    }

    /**
     * Show the form for creating a new resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function create()
    {
        if (Auth::user()->hasRole('school')) {
            return redirect()->route('backend.dashboard');
        }
        $institutes = SchoolCategory::orderBy('name')->where('status', '=', 1)->pluck('name', 'id');
        $subjects = Subject::orderBy('subject_name')->where('status', '=', 1)->pluck('subject_name', 'id');

        return view('backend.topics.create', compact('subjects', 'institutes'));
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        $subject_id = $request->subject;

        $subject_details = Subject::where('id', $subject_id)->first();
        $course_id = $subject_details->subject_class->course_id;

        $course_details = Course::where('id', $course_id)->select('school_id')->first();
        if (!Auth::user()->hasAccessToSchool($course_details->school_id)) {
            return redirect()->route('backend.dashboard');
        }

        if (!empty($request->input('ajax_request'))) {
            $validator = Validator::make($request->all(), [
                        'topic_name' => [
                            'required',
                            'max:180',
                            Rule::unique('topics')->where(function ($query) use($subject_id) {
                                        return $query->where('subject_id', $subject_id);
                                    })
                        ],
            ]);
        } else {
            $validator = Validator::make($request->all(), [
                        'subject' => 'required',
                        'topic_name' => [
                            'required',
                            'max:180',
                            Rule::unique('topics')->where(function ($query) use($subject_id) {
                                        return $query->where('subject_id', $subject_id);
                                    })
                        ],
            ]);
        }

        // if the validator fails, redirect back to the form
        if ($validator->fails()) {
            return Redirect::back()
                            ->withErrors($validator) // send back all errors to the form
                            ->withInput();
        }

        //form data is available in the request object
        $topic = new Topic();

        $topic->subject_id = $request->subject;
        $topic->topic_name = $request->input('topic_name');
        $topic->status = ($request->input('status') !== null) ? $request->input('status') : 0;

        $topic->save();

        if (!empty($request->input('ajax_request'))) {
            return redirect()->route('backend.subjects.show', $topic->subject_id)->with('success', 'Topic created Successfully');
        } else {
            return redirect()->route('backend.topics.index')->with('success', 'Topic created Successfully');
        }
    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        // $topic = Topic::findOrFail($id);
        return redirect()->route('backend.topics.index');
    }

    /**
     * Show the form for editing the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function edit($id)
    {
        if (Auth::user()->hasRole('school')) {
            return redirect()->route('backend.dashboard');
        }
        //Find the employee
        $topic = Topic::find($id);

        $institutes = SchoolCategory::orderBy('name')->where('status', '=', 1)->pluck('name', 'id');
        $subject_details = Subject::where("id", $topic->subject_id)->select('class_id')->first();
        $topic->class_id = $subject_details->class_id;
        //echo $subject_details->class_id; exit;
        $classes_details = Classes::where("id", $subject_details->class_id)->select('course_id')->first();
        $topic->course_id = $classes_details->course_id;
        //echo $topic->course_id; exit;
        $course_details = Course::where("id", $topic->course_id)->select('school_id', 'department_id')->first();
        $topic->school_id = $course_details->school_id;

        $topic->department_id = $course_details->department_id;

        $departments = Department::where('school_id', $topic->school_id)->where('status', '=', 1)->pluck('name', 'id');

        $school_details = School::where("id", $topic->school_id)->select('school_category')->first();
        $topic->category_id = $school_details->school_category;

        $schools = School::where('school_category', $topic->category_id)->orderBy('school_name')->where('status', '=', 1)->pluck('school_name', 'id');
        $courses = Course::where('school_id', $topic->school_id)->orderBy('name')->where('status', '=', 1)->pluck('name', 'id');
        $classes = Classes::where('course_id', $topic->course_id)->orderBy('class_name')->where('status', '=', 1)->pluck('class_name', 'id');

        $subjects = Subject::orderBy('subject_name')->where('class_id', $subject_details->class_id)->where('status', '=', 1)->pluck('subject_name', 'id');

        return view('backend.topics.edit', compact('topic', 'subjects', 'institutes', 'schools', 'courses', 'classes', 'departments'));
    }

    /**
     * Show the form for editing the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function edit_ajax(Request $request)
    {
        $id = $request->input('topic_id');
        $topic = Topic::find($id);

        return view('backend.topics.edit-ajax', compact('topic'));
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
        $subject_id = $request->subject;

        $subject_details = Subject::where('id', $subject_id)->first();
        $course_id = $subject_details->subject_class->course_id;

        $course_details = Course::where('id', $course_id)->select('school_id')->first();
        if (!Auth::user()->hasAccessToSchool($course_details->school_id)) {
            return redirect()->route('backend.dashboard');
        }

        $topic = Topic::find($id);

        if (!empty($request->input('ajax_request'))) {
            $validator = Validator::make($request->all(), [
                        'topic_name' => [
                            'required',
                            'max:180',
                            Rule::unique('topics')->where(function ($query) use($subject_id, $id) {
                                        return $query->where('subject_id', $subject_id)->where('id', '<>', $id);
                                    })
                        ],
            ]);
        } else {
            $validator = Validator::make($request->all(), [
                        //'subject' => 'required',
                        'topic_name' => [
                            'required',
                            'max:180',
                            Rule::unique('topics')->where(function ($query) use($subject_id, $id) {
                                        return $query->where('subject_id', $subject_id)->where('id', '<>', $id);
                                    })
                        ],
            ]);

            // $topic->subject_id = $request->subject;
        }

        // if the validator fails, redirect back to the form
        if ($validator->fails()) {
            return Redirect::back()
                            ->withErrors($validator) // send back all errors to the form
                            ->withInput();
        }


        $topic->topic_name = $request->input('topic_name');
        $topic->status = ($request->input('status') !== null) ? $request->input('status') : 0;
        $topic->save(); //persist the data

        if (!empty($request->input('ajax_request'))) {
            return redirect()->route('backend.subjects.show', $topic->subject_id)->with('success', 'Topic Information Updated Successfully');
        } else {
            return redirect()->route('backend.topics.index')->with('success', 'Topic Information Updated Successfully');
        }
    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy(Request $request, $id)
    {
        $topic = Topic::find($id);

        $subject_details = Subject::where('id', $topic->subject_id)->first();
        $course_id = $subject_details->subject_class->course_id;

        $course_details = Course::where('id', $course_id)->select('school_id')->first();
        if (!Auth::user()->hasAccessToSchool($course_details->school_id)) {
            return redirect()->route('backend.dashboard');
        }

        $topic->delete();

        if (!empty($request->input('ajax_request'))) {
            return redirect()->route('backend.subjects.show', $topic->subject_id)->with('success', 'Topic Deleted Successfully');
        } else {
            return redirect()->route('backend.topics.index')->with('success', 'Topic Deleted Successfully');
        }
    }
    
    
    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function saveOrdering(Request $request)
    {
        $weights = $request->get('weight');
        foreach ($weights as $id => $weight) {
            Topic::where('id', '=', $id)->update(['weight' => $weight]);
        }
        exit;
    }

}

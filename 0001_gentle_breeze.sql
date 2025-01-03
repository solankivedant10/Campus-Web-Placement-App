/*
  # Initial Schema for Campus Placement App

  1. New Tables
    - profiles
      - Student and company profiles
      - Linked to auth.users
    - jobs
      - Job postings from companies
    - applications
      - Student job applications
    - interviews
      - Scheduled interviews

  2. Security
    - Enable RLS on all tables
    - Policies for students and companies
*/

-- Create profiles table
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  full_name text NOT NULL,
  user_type text NOT NULL CHECK (user_type IN ('student', 'company')),
  email text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Additional student profile fields
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS student_id text NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS course text NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS graduation_year int NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS cgpa decimal(4,2) NULL;

-- Additional company profile fields
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS company_name text NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS industry text NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS website text NULL;

-- Create jobs table
CREATE TABLE jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid REFERENCES profiles(id),
  title text NOT NULL,
  description text NOT NULL,
  requirements text NOT NULL,
  location text NOT NULL,
  salary_range text,
  status text DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create applications table
CREATE TABLE applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid REFERENCES jobs(id),
  student_id uuid REFERENCES profiles(id),
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'accepted', 'rejected')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create interviews table
CREATE TABLE interviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid REFERENCES applications(id),
  scheduled_at timestamptz NOT NULL,
  location text NOT NULL,
  type text NOT NULL CHECK (type IN ('technical', 'hr', 'final')),
  notes text,
  status text DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE interviews ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Jobs policies
CREATE POLICY "Jobs are viewable by everyone"
  ON jobs FOR SELECT
  USING (true);

CREATE POLICY "Companies can create jobs"
  ON jobs FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND user_type = 'company'
    )
  );

CREATE POLICY "Companies can update own jobs"
  ON jobs FOR UPDATE
  USING (company_id = auth.uid());

-- Applications policies
CREATE POLICY "Students can view own applications"
  ON applications FOR SELECT
  USING (student_id = auth.uid());

CREATE POLICY "Companies can view applications for their jobs"
  ON applications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM jobs
      WHERE jobs.id = applications.job_id
      AND jobs.company_id = auth.uid()
    )
  );

CREATE POLICY "Students can create applications"
  ON applications FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND user_type = 'student'
    )
  );

-- Interviews policies
CREATE POLICY "Students can view own interviews"
  ON interviews FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM applications
      WHERE applications.id = interviews.application_id
      AND applications.student_id = auth.uid()
    )
  );

CREATE POLICY "Companies can manage interviews"
  ON interviews FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM applications
      JOIN jobs ON jobs.id = applications.job_id
      WHERE applications.id = interviews.application_id
      AND jobs.company_id = auth.uid()
    )
  );
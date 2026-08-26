function [labels] = parseBIDSLabelsFromRow(pipeline, tableRow)
labels.Subject = sprintf("sub-%02d", tableRow.Subject_Number);
labels.Session = sprintf("ses-%02d", tableRow.Session_Number);
labels.Task = sprintf("task-%s", pipeline.TaskName);
labels.Run = sprintf("run-%02d", tableRow.Run_Number);
labels.FullName = sprintf("%s_%s_%s_%s", labels.Subject, labels.Session, labels.Task, labels.Run);
